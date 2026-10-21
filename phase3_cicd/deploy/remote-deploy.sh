#!/usr/bin/env bash
set -euo pipefail

# ---------------------------------------------------------------------------
# Phase 3 - remote deployment script (runs on the EC2 server)
#
# Invoked by GitHub Actions over SSH after the new images have been pushed
# to Amazon ECR. It pulls the new images and replaces the running containers
# so the updated application goes live.
#
# Required environment variables (passed by the workflow):
#   ECR_REGISTRY, ECR_REPOSITORY, IMAGE_TAG, POSTGRES_PASSWORD, JWT_SECRET
# Provided for the ECR login:
#   AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY, AWS_REGION
# ---------------------------------------------------------------------------

: "${ECR_REGISTRY:?ECR_REGISTRY is required}"
: "${ECR_REPOSITORY:?ECR_REPOSITORY is required}"
: "${IMAGE_TAG:?IMAGE_TAG is required}"
: "${POSTGRES_PASSWORD:?POSTGRES_PASSWORD is required}"
: "${JWT_SECRET:?JWT_SECRET is required}"

AWS_REGION="${AWS_REGION:-eu-west-1}"

NETWORK="${NETWORK:-zeetafin-net}"
DB_VOLUME="${DB_VOLUME:-zeetafin-pgdata}"
DB_IMAGE="${DB_IMAGE:-postgres:16-alpine}"

DB_CONTAINER="${DB_CONTAINER:-zeetafin-db}"
BE_CONTAINER="${BE_CONTAINER:-zeetafin-be}"
FE_CONTAINER="${FE_CONTAINER:-zeetafin-fe}"
PROXY_CONTAINER="${PROXY_CONTAINER:-zeetafin-proxy}"
PROXY_IMAGE="${PROXY_IMAGE:-nginx:1.27-alpine}"

BE_IMAGE_REF="${ECR_REGISTRY}/${ECR_REPOSITORY}:zeetafin-be-${IMAGE_TAG}"
FE_IMAGE_REF="${ECR_REGISTRY}/${ECR_REPOSITORY}:zeetafin-fe-${IMAGE_TAG}"

POSTGRES_USER="${POSTGRES_USER:-postgres}"
POSTGRES_DB="${POSTGRES_DB:-zeetafin}"

NGINX_CONF_PATH="${NGINX_CONF_PATH:-/tmp/phase3-deploy/nginx.conf}"
NGINX_CONF_LABEL="zeetafin.nginx.conf.sha256"
NGINX_CONF_SHA="$(sha256sum "${NGINX_CONF_PATH}" 2>/dev/null | awk '{print $1}')"

# --- Helpers ------------------------------------------------------------------
# True when the container exists, is running, and was started from exactly the
# same image (compared by image ID, not by tag).
container_is_current() {
  local container="$1"
  local image_ref="$2"

  local state running_image desired_image
  state="$(docker inspect --format '{{.State.Running}}' "${container}" 2>/dev/null || true)"
  [ "${state}" = "true" ] || return 1

  running_image="$(docker inspect --format '{{.Image}}' "${container}" 2>/dev/null || true)"
  desired_image="$(docker image inspect --format '{{.Id}}' "${image_ref}" 2>/dev/null || true)"

  [ -n "${desired_image}" ] || return 1
  [ "${running_image}" = "${desired_image}" ]
}

# Keeps the deployment idempotent: a container that is already running the
# exact target image is left untouched, anything else is removed so that it can
# be recreated with the new image.
# Returns 0 when the container was kept, 1 when it was removed.
prepare_container() {
  local container="$1"
  local image_ref="$2"

  if container_is_current "${container}" "${image_ref}"; then
    echo "Container ${container} is already running the target image - keeping it"
    return 0
  fi

  echo "Removing ${container} (if any)..."
  docker rm -f "${container}" 2>/dev/null || true
  return 1
}

# The proxy container also mounts nginx.conf into it, so keeping the container
# is only safe when that file has not changed since the container was created.
# The checksum of the file is stored as a label on the container.
proxy_is_current() {
  local container="$1"
  local image_ref="$2"

  container_is_current "${container}" "${image_ref}" || return 1

  local container_sha
  container_sha="$(docker inspect --format "{{index .Config.Labels \"${NGINX_CONF_LABEL}\"}}" "${container}" 2>/dev/null || true)"

  [ -n "${NGINX_CONF_SHA}" ] || return 1
  [ "${container_sha}" = "${NGINX_CONF_SHA}" ]
}

# --- AWS CLI (needed to authenticate Docker with ECR) -----------------------
if ! command -v aws >/dev/null 2>&1; then
  echo "AWS CLI not found - installing..."
  sudo apt-get update -y
  sudo apt-get install -y unzip curl
  curl -fsSL "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o /tmp/awscliv2.zip
  unzip -q -o /tmp/awscliv2.zip -d /tmp
  sudo /tmp/aws/install
fi

# --- Authenticate Docker with Amazon ECR -------------------------------------
echo "Logging in to Amazon ECR..."
aws ecr get-login-password --region "${AWS_REGION}" \
  | docker login --username AWS --password-stdin "${ECR_REGISTRY}"

# --- Pull the new images ------------------------------------------------------
echo "Pulling ${BE_IMAGE_REF}"
docker pull "${BE_IMAGE_REF}"
echo "Pulling ${FE_IMAGE_REF}"
docker pull "${FE_IMAGE_REF}"

# --- Network and volume (persist across deployments) --------------------------
docker network create "${NETWORK}" 2>/dev/null || true
docker volume create "${DB_VOLUME}" 2>/dev/null || true

# --- Database ------------------------------------------------------------------
if prepare_container "${DB_CONTAINER}" "${DB_IMAGE}"; then
  echo "PostgreSQL is already up to date - skipping"
else
  echo "Starting PostgreSQL..."
  docker run -d --name "${DB_CONTAINER}" --network "${NETWORK}" \
    --restart unless-stopped \
    -e POSTGRES_USER="${POSTGRES_USER}" \
    -e POSTGRES_PASSWORD="${POSTGRES_PASSWORD}" \
    -e POSTGRES_DB="${POSTGRES_DB}" \
    -v "${DB_VOLUME}:/var/lib/postgresql/data" \
    "${DB_IMAGE}"
fi

echo "Waiting for the database to become ready..."
for _ in $(seq 1 30); do
  if docker exec "${DB_CONTAINER}" pg_isready -U "${POSTGRES_USER}" -d "${POSTGRES_DB}" >/dev/null 2>&1; then
    break
  fi
  sleep 2
done

# --- Backend -------------------------------------------------------------------
if prepare_container "${BE_CONTAINER}" "${BE_IMAGE_REF}"; then
  echo "Backend is already up to date - skipping"
else
  echo "Starting backend..."
  docker run -d --name "${BE_CONTAINER}" --network "${NETWORK}" \
    --restart unless-stopped \
    -e NODE_ENV=production \
    -e DB_HOST="${DB_CONTAINER}" -e DB_PORT=5432 \
    -e DB_USERNAME="${POSTGRES_USER}" -e DB_PASSWORD="${POSTGRES_PASSWORD}" \
    -e DB_NAME="${POSTGRES_DB}" \
    -e JWT_SECRET="${JWT_SECRET}" -e PORT=3001 \
    "${BE_IMAGE_REF}"
fi

# --- Frontend ------------------------------------------------------------------
if prepare_container "${FE_CONTAINER}" "${FE_IMAGE_REF}"; then
  echo "Frontend is already up to date - skipping"
else
  echo "Starting frontend..."
  docker run -d --name "${FE_CONTAINER}" --network "${NETWORK}" \
    --restart unless-stopped \
    "${FE_IMAGE_REF}"
fi

# --- Nginx reverse proxy (only public entry point, port 80) -------------------
# Phase 1 (Ansible) installs nginx as a system service, which permanently holds
# host port 80. Free it before publishing the proxy container on :80.
echo "Freeing port 80 from the system nginx service (if running)..."
if command -v systemctl >/dev/null 2>&1; then
  sudo systemctl stop nginx 2>/dev/null || true
  sudo systemctl disable nginx 2>/dev/null || true
fi

if proxy_is_current "${PROXY_CONTAINER}" "${PROXY_IMAGE}"; then
  echo "Nginx proxy is already up to date - skipping"
else
  echo "Removing ${PROXY_CONTAINER} (if any)..."
  docker rm -f "${PROXY_CONTAINER}" 2>/dev/null || true
  echo "Starting nginx reverse proxy..."
  docker run -d --name "${PROXY_CONTAINER}" --network "${NETWORK}" \
    --restart unless-stopped \
    --label "${NGINX_CONF_LABEL}=${NGINX_CONF_SHA}" \
    -p 80:80 \
    -v "${NGINX_CONF_PATH}:/etc/nginx/conf.d/default.conf:ro" \
    "${PROXY_IMAGE}"
fi

# --- Verify the deployment -----------------------------------------------------
echo "Waiting for the application to become reachable..."
verified=""
for _ in $(seq 1 20); do
  if curl -fsS http://localhost/ >/dev/null 2>&1 \
     && curl -fsS http://localhost/api/docs >/dev/null 2>&1; then
    verified=1
    break
  fi
  sleep 3
done

if [ -z "${verified}" ]; then
  echo "Deployment verification FAILED" >&2
  echo "--- backend logs ---" >&2
  docker logs "${BE_CONTAINER}" --tail 50 >&2 || true
  exit 1
fi

echo "Deployment successful - image tag ${IMAGE_TAG} is live"
docker ps --format 'table {{.Names}}\t{{.Image}}\t{{.Status}}'
