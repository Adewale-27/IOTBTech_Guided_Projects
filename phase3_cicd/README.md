# Phase 3 - CI/CD with GitHub Actions

## Project Overview

This phase creates a GitHub Actions CI/CD pipeline that automatically:

1. Checks out the application code
2. Builds the Docker images for the backend and frontend
3. Authenticates with AWS
4. Pushes the images to Amazon ECR
5. Connects to the EC2 server over SSH
6. Pulls the new images and replaces the old containers
7. Verifies that the application is accessible

No manual deployment is required. Every push to the `main` branch triggers the pipeline.

## Expected Workflow

```text
Developer pushes code
        |
        v
     GitHub
        |
        v
  GitHub Actions
        |
        +--------------------+
        |                    |
        v                    v
 Build Docker Images   Authenticate AWS
        |                    |
        +---------+----------+
                  |
                  v
            Push to ECR
                  |
                  v
           Connect to EC2 (SSH)
                  |
                  v
          Pull New Images
                  |
                  v
        Stop Old Containers
                  |
                  v
         Start New Containers
                  |
                  v
     Verify Application on Port 80
                  |
                  v
       Application Running on AWS
```

## Project Structure

```text
.
├── .github/
│   └── workflows/
│       └── deploy.yml              # The CI/CD pipeline
│
├── phase1_terraform_ansible/       # Server provisioned with Terraform + Ansible
├── phase2_docker/                  # Dockerized application + ECR repository
│
└── phase3_cicd/
    ├── deploy/
    │   ├── remote-deploy.sh        # Runs on EC2: pull images, replace containers
    │   └── nginx.conf              # Reverse proxy: port 80 -> FE + BE
    ├── evidence/                   # Screenshots of the pipeline and deployment
    └── README.md

└── README.md
```

## How the Pipeline Works

### Workflow File

`.github/workflows/deploy.yml`

### Triggers

- Every push to the `main` branch
- Manual run from the GitHub Actions tab (`workflow_dispatch`)

### Steps

| # | Step | What it does |
|---|------|--------------|
| 1 | Checkout application code | Downloads the repository on the runner |
| 2 | Configure AWS credentials | Uses `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` from GitHub Secrets |
| 3 | Login to Amazon ECR | Gets a Docker login token for ECR |
| 4 | Build and push backend image | Multi-stage build of `ZeetaFin-BE`, tagged `zeetafin-be-<commit-sha>` |
| 5 | Build and push frontend image | Multi-stage build of `ZeetaFin-FE`, tagged `zeetafin-fe-<commit-sha>` |
| 6 | Copy deploy files to EC2 | SCPs `remote-deploy.sh` and `nginx.conf` to the server |
| 7 | Deploy new containers to EC2 | Runs `remote-deploy.sh` on the server over SSH |
| 8 | Verify application is accessible | Curls the frontend and the API through port 80 |

### Image Tagging

Each image is tagged with the commit SHA:

```text
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:zeetafin-be-<commit-sha>
<ACCOUNT_ID>.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:zeetafin-fe-<commit-sha>
```

Because the ECR repository uses immutable tags, every deployment gets a unique tag.

## What Happens on the EC2 Server

`phase3_cicd/deploy/remote-deploy.sh` is executed on EC2 by the pipeline:

1. Installs the AWS CLI if it is missing
2. Authenticates Docker with Amazon ECR
3. Pulls the new backend and frontend images
4. Stops the **old** containers (`zeetafin-db`, `zeetafin-be`, `zeetafin-fe`, `zeetafin-proxy`)
5. Starts PostgreSQL (data persists in the `zeetafin-pgdata` volume)
6. Starts the new backend and frontend containers
7. Starts an nginx reverse proxy on port 80
8. Waits until `http://localhost/` and `http://localhost/api/docs` respond

Old containers are always removed before the new ones start, so a new version replaces the previous one on every deployment.

## Nginx Reverse Proxy

Only port 80 is exposed publicly. nginx forwards traffic inside the Docker network:

| Public URL | Container | Port |
|------------|-----------|------|
| `http://EC2_IP/` | zeetafin-fe | 3000 |
| `http://EC2_IP/api/...` | zeetafin-be | 3001 |

The frontend is built with `NEXT_PUBLIC_API_URL=/api`, so the browser calls the same host and nginx routes `/api` requests to the backend.

## GitHub Secrets

All credentials are stored as GitHub Secrets. Nothing sensitive is committed to the repository.

| Secret | Description |
|--------|-------------|
| `AWS_ACCESS_KEY_ID` | IAM user access key (ECR push + deploy) |
| `AWS_SECRET_ACCESS_KEY` | IAM user secret key |
| `EC2_HOST` | Public IP address of the EC2 instance |
| `EC2_USER` | SSH user (usually `ubuntu`) |
| `EC2_SSH_KEY` | Private key (`.pem`) matching the EC2 key pair |
| `POSTGRES_PASSWORD` | Database password used on the server |
| `JWT_SECRET` | Secret used by the backend to sign tokens |

### How to add them

```text
GitHub repository -> Settings -> Secrets and variables -> Actions -> New repository secret
```

## Prerequisites

- The Phase 1 EC2 instance is running (Docker installed by the Ansible playbook)
- The Phase 2 ECR repository exists (`terraform -chdir=phase2_docker/ecr apply`)
- The EC2 key pair private key (`.pem`) is available
- An IAM user with permission to push to the ECR repository
- AWS credentials configured as GitHub Secrets

## Running the Pipeline

### Automatic

```bash
git add .
git commit -m "Update application"
git push origin main
```

The workflow starts automatically.

### Manual

```text
GitHub -> Actions -> CI/CD - Build, Push to ECR and Deploy to EC2 -> Run workflow
```

## Verification

After the workflow finishes:

1. The workflow log shows the `Verify application is accessible` step passing
2. Open the EC2 public IP:

```text
http://EC2_PUBLIC_IP          -> ZeetaFin frontend
http://EC2_PUBLIC_IP/api/docs -> Swagger API documentation
```

3. On EC2, confirm the containers:

```bash
docker ps
```

Expected containers:

```text
zeetafin-db
zeetafin-be
zeetafin-fe
zeetafin-proxy
```

4. In Amazon ECR, confirm the images with the commit SHA tags are present.

## Evidence

Screenshots demonstrating the completed pipeline are stored in `evidence/`:

- Successful GitHub Actions workflow run
- Docker images pushed to Amazon ECR
- Containers running on EC2
- Application accessible in the browser

## Troubleshooting

| Problem | Check |
|---------|-------|
| Workflow fails at AWS login | `AWS_ACCESS_KEY_ID` / `AWS_SECRET_ACCESS_KEY` secrets |
| Workflow fails at SSH step | `EC2_HOST`, `EC2_USER`, `EC2_SSH_KEY` secrets; key pair matches the instance |
| ECR push denied | IAM user has `ecr:PutImage` permissions on the repository |
| Containers start but app unreachable | `docker logs zeetafin-be`, `docker logs zeetafin-proxy` |
| Backend cannot reach database | Backend and database must be on the `zeetafin-net` network |

## Cleanup

To stop the pipeline from deploying, disable the workflow from the GitHub Actions tab.

To remove the AWS resources:

```bash
terraform -chdir=phase2_docker/ec2 destroy
terraform -chdir=phase2_docker/ecr destroy
```

To remove the containers on EC2:

```bash
docker rm -f zeetafin-proxy zeetafin-fe zeetafin-be zeetafin-db
```

This helps prevent unnecessary AWS charges.

## Security Notes

- All credentials are stored in GitHub Secrets
- `.env` files, `.pem` keys, and Terraform state files are git-ignored
- The EC2 security group only allows SSH (22), HTTP (80), and HTTPS (443)
- Containers bind only through the nginx proxy on port 80
- The backend runs as a non-root user inside the container

## Conclusion

This phase demonstrates a complete CI/CD pipeline:

- **GitHub Actions** orchestrates the build, push, and deployment
- **Amazon ECR** stores versioned Docker images
- **SSH deployment** replaces old containers with the new version
- **Nginx** exposes the application securely on port 80
- **GitHub Secrets** keep all credentials out of the repository

Pushing a change to `main` now automatically builds, publishes, and deploys the updated application to AWS.
