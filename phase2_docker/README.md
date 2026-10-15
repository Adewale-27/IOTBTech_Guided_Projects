# ZeetaFin Application Containerization and Amazon ECR

## Project Overview

This project demonstrates how to containerize the ZeetaFin ERP application using Docker and push the resulting Docker images to Amazon Elastic Container Registry (ECR).

This is Phase 2 of the AWS DevOps project.

ZeetaFin is a full-stack application made up of three parts:

- **ZeetaFin-BE** — a NestJS backend API
- **ZeetaFin-FE** — a Next.js frontend
- **PostgreSQL** — the database

Each part of the application is analyzed to identify its dependencies, required port, and start command. A Dockerfile is then created to package each application into a Docker image.

The images are tested locally using a deployment script that starts the database, backend, and frontend together. After successful testing, an Amazon ECR repository is created with Terraform and the Docker images are pushed to ECR.

The final goal is to demonstrate the following workflow:

```text
ZeetaFin-BE (NestJS)          ZeetaFin-FE (Next.js)
        |                              |
        v                              v
  Backend Dockerfile            Frontend Dockerfile
        |                              |
        v                              v
   Backend Image                 Frontend Image
        |                              |
        +--------------+---------------+
                       |
                       v
                Docker Containers
             (BE + FE + PostgreSQL)
                       |
                       v
                Local Application
                       |
                       v
                   Amazon ECR
                       |
                       v
                 Pushed Images
```

## Project Structure

```text
phase2_docker/
├── Application/
│   ├── .env
│   ├── deploy.sh
│   │
│   ├── ZeetaFin-BE/
│   │   ├── Dockerfile
│   │   ├── .dockerignore
│   │   ├── docker-entrypoint.sh
│   │   └── application source code
│   │
│   └── ZeetaFin-FE/
│       ├── Dockerfile
│       ├── .dockerignore
│       └── application source code
│
├── ECR/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   ├── version.tf
│   └── terraform.tfvars
│
├── EC2/
│   ├── main.tf
│   ├── variables.tf
│   ├── outputs.tf
│   └── terraform.tfvars
│
└── README.md
```

## Technologies Used

- AWS
- Amazon ECR
- Terraform
- Docker
- Git
- NestJS
- Next.js
- TypeScript
- PostgreSQL
- TypeORM

## Prerequisites

The following tools are required:

- Docker
- AWS CLI
- Terraform
- Git

You also need:

- An AWS account
- AWS credentials
- Access to Amazon ECR
- The provided application source code

## Check Installed Tools

```bash
docker --version
aws --version
terraform --version
git --version
```

## AWS Authentication

Configure your AWS credentials:

```bash
aws configure
```

Enter your:

- AWS Access Key ID
- AWS Secret Access Key
- Default region
- Output format

Verify that the AWS CLI is authenticated:

```bash
aws sts get-caller-identity
```

A successful command should return information about the authenticated AWS account.

Do not upload AWS credentials or private keys to GitHub.

## Application

Before creating the Docker images, the provided application was inspected.

The following information was identified:

| Component | Runtime | Dependencies | Port | Start command |
|-----------|---------|--------------|------|---------------|
| ZeetaFin-BE | Node.js 20 | npm (`npm ci`) | 3001 | `node dist/main` |
| ZeetaFin-FE | Node.js 22 | npm (`npm ci`) | 3000 | `node server.js` |
| Database | PostgreSQL 16 | — | 5432 | — |

### Backend — ZeetaFin-BE

The backend is a NestJS API written in TypeScript.

- Framework: NestJS
- Database access: TypeORM
- Authentication: JWT (Passport)
- API docs: Swagger

The backend listens on port `3001` by default and serves its routes under the `/api` prefix.

The API documentation is available at:

```text
http://localhost:3001/api/docs
```

### Frontend — ZeetaFin-FE

The frontend is a Next.js 14 application built with the App Router.

- Framework: Next.js 14
- Styling: Tailwind CSS
- Output mode: `standalone`

The frontend listens on port `3000` by default.

### Database

The application uses PostgreSQL version 16, provided by the `postgres:16-alpine` image.

The backend connects to the database using the `DB_HOST`, `DB_PORT`, `DB_USERNAME`, `DB_PASSWORD`, and `DB_NAME` environment variables.

## Dockerfile

A Dockerfile defines how each application is packaged into a Docker image.

Both applications use a multi-stage build to keep the final images small.

### Backend Dockerfile

```dockerfile
# syntax=docker/dockerfile:1

FROM node:20-alpine AS deps
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci

FROM node:20-alpine AS builder
WORKDIR /app
COPY --from=deps /app/node_modules ./node_modules
COPY . .
RUN npm run build

FROM node:20-alpine AS runner
ENV NODE_ENV=production
WORKDIR /app
COPY package.json package-lock.json ./
RUN npm ci --omit=dev && npm cache clean --force
COPY --from=builder /app/dist ./dist
COPY phase2_docker/Application/ZeetaFin-BE/docker-entrypoint.sh ./
RUN chmod +x phase2_docker/Application/ZeetaFin-BE/docker-entrypoint.sh && sed -i 's/\r$//' phase2_docker/Application/ZeetaFin-BE/docker-entrypoint.sh
USER node
EXPOSE 3001
ENTRYPOINT ["./phase2_docker/Application/ZeetaFin-BE/docker-entrypoint.sh"]
CMD ["node", "dist/main"]
```

The backend image:

- Installs dependencies from `package-lock.json` using `npm ci`
- Builds the NestJS application with `npm run build`
- Installs only production dependencies in the final stage
- Runs the API as the non-root `node` user
- Seeds the database before starting, using `docker-entrypoint.sh`
- Exposes port `3001`

> Note: the backend Dockerfile copies the entrypoint using a repository-root-relative path (`phase2_docker/Application/ZeetaFin-BE/docker-entrypoint.sh`). The build context must therefore be the repository root (the folder that contains `phase2_docker`).

### Frontend Dockerfile

```dockerfile
# Dockerfile

ARG NODE_VERSION=22

# ---------- BASE ----------
FROM node:${NODE_VERSION}-alpine AS base
WORKDIR /app

# ---------- Dependencies stage ----------
FROM base AS deps
COPY package.json package-lock.json ./
COPY next.config.js ./
RUN npm ci

# ---------- Build stage ----------
FROM base AS builder
ARG NEXT_PUBLIC_API_URL=http://localhost:3001/api
ENV NEXT_PUBLIC_API_URL=$NEXT_PUBLIC_API_URL
ENV NEXT_TELEMETRY_DISABLED=1

COPY --from=deps /app/node_modules ./node_modules
COPY . .

RUN npm run build

# ---------- Runtime stage ----------
FROM base AS runner
ENV NODE_ENV=production
ENV NEXT_TELEMETRY_DISABLED=1
ENV PORT=3000
ENV HOSTNAME=0.0.0.0

RUN apk add --no-cache tini

RUN addgroup --system --gid 1001 nodejs \
    && adduser --system --uid 1001 nextjs

COPY --from=builder --chown=nextjs:nodejs /app/.next/standalone ./
COPY --from=builder --chown=nextjs:nodejs /app/.next/static ./.next/static

USER nextjs

EXPOSE 3000

HEALTHCHECK --interval=30s --timeout=3s --start-period=10s --retries=3 \
  CMD wget -qO- http://localhost:3000/health || exit 1

CMD ["node", "server.js"]
```

The frontend image:

- Installs dependencies from `package-lock.json` using `npm ci`
- Builds the Next.js application in `standalone` mode
- Copies only the standalone output and static assets into the runtime stage
- Runs the server as the non-root `nextjs` user
- Exposes port `3000`
- Includes a container healthcheck

## .dockerignore

A `.dockerignore` file prevents unnecessary files from being copied into the Docker image.

### Backend

```text
node_modules
dist
coverage
npm-debug.log
.git
.gitignore
.env
.env.*
!.env.example
Dockerfile
.dockerignore
README.md
```

### Frontend

```text
node_modules
dist
coverage
npm-debug.log
.git
.gitignore
.env
.env.*
Dockerfile
.dockerignore
README.md
```

Sensitive files such as `.env` files and credentials are not included in the Docker images.

## Build the Docker Images

### Build the Backend Image

Run from the repository root:

```bash
docker build -f phase2_docker/Application/ZeetaFin-BE/Dockerfile -t zeetafin-be:latest .
```

### Build the Frontend Image

Run from the frontend directory:

```bash
cd phase2_docker/Application/ZeetaFin-FE
docker build -t zeetafin-fe:latest .
```

Docker will read each Dockerfile and build the images.

A successful build should finish without errors.

## Verify the Docker Images

List the locally available Docker images:

```bash
docker images
```

Both application images should appear in the list.

Example:

```text
REPOSITORY     TAG       IMAGE ID       CREATED        SIZE
zeetafin-fe    latest    ........       ...            ...
zeetafin-be    latest    ........       ...            ...
```

## Configure the Environment

The deployment configuration is read from environment variables.

Copy the example file and set real values:

```bash
cd phase2_docker/Application
cp .env.example .env
```

The following values must be set:

- `POSTGRES_PASSWORD` — password for the database
- `JWT_SECRET` — secret key used to sign JWT tokens

Other values (defaults shown):

```env
POSTGRES_USER=postgres
POSTGRES_DB=zeetafin
BIND_ADDR=127.0.0.1
BACKEND_PORT=3001
FRONTEND_PORT=3000
RESTART_POLICY=unless-stopped
```

The `.env` file contains secrets and must never be committed to GitHub.

## Run the Application Locally

The `deploy.sh` script starts the whole stack: the database, the backend, and the frontend.

Run it from the `Application` directory:

```bash
./deploy.sh
```

The script performs the following steps:

1. Creates the Docker network (`zeetafin-net`)
2. Creates the database volume (`zeetafin-pgdata`)
3. Removes any existing containers with the same names
4. Starts the PostgreSQL container (`zeetafin-db`)
5. Waits until the database is ready
6. Starts the backend container (`zeetafin-be`)
7. Starts the frontend container (`zeetafin-fe`)

The backend seeds the database automatically on startup.

The port mapping follows this format:

```text
HOST_PORT:CONTAINER_PORT
```

With the default configuration:

```text
3001:3001   # backend
3000:3000   # frontend
```

Containers are bound to `127.0.0.1` by default, so they are reachable only from the host.

## Verify the Containers

Check the running containers:

```bash
docker ps
```

The stack should be listed as running.

Example:

```text
CONTAINER ID   IMAGE                  STATUS         PORTS
........       zeetafin-fe:latest     Up ...         127.0.0.1:3000->3000/tcp
........       zeetafin-be:latest     Up ...         127.0.0.1:3001->3001/tcp
........       postgres:16-alpine     Up ...         5432/tcp
```

## Test the Application

Open the frontend in a web browser:

```text
http://localhost:3000
```

The backend API is reachable at:

```text
http://localhost:3001/api
```

The backend API documentation (Swagger) is available at:

```text
http://localhost:3001/api/docs
```

The default admin account created by the seed script is:

```text
email:    admin@zeeta.com
password: admin123
```

A successful login confirms that the frontend, backend, and database are all running correctly inside their Docker containers.

## View Container Logs

If the application does not work as expected, check the container logs:

```bash
docker logs zeetafin-db
docker logs zeetafin-be
docker logs zeetafin-fe
```

The logs can be used to identify database startup errors, seeding errors, dependency issues, or configuration problems.

## Stop the Application

Stop and remove the stack:

```bash
docker rm -f zeetafin-fe zeetafin-be zeetafin-db
```

To also remove the network, volume, and images:

```bash
docker network rm zeetafin-net
docker volume rm zeetafin-pgdata
docker rmi zeetafin-be:latest zeetafin-fe:latest
```

## Amazon ECR

Amazon Elastic Container Registry (ECR) is used to store the Docker images in AWS.

The ECR repository is created with Terraform, defined in the `ECR/` directory.

The repository is configured with:

- Immutable image tags (existing tags cannot be overwritten)
- Image scanning on push
- AES256 encryption by default (optional KMS key)
- A lifecycle policy that expires untagged images after 7 days and keeps only the most recent tagged images

The repository values are defined in `ECR/terraform.tfvars`:

```hcl
aws_region        = "eu-west-1"
repository_name   = "adecloud/zeetafin"
kms_key_arn       = null
max_tagged_images = 30
```

The workflow is:

```text
Docker Images
     |
     v
Amazon ECR Repository
     |
     v
Pushed Images
```

### Create an ECR Repository with Terraform

Initialize Terraform in the ECR directory:

```bash
terraform -chdir=phase2_docker/ECR init
```

Review the plan:

```bash
terraform -chdir=phase2_docker/ECR plan
```

Create the repository:

```bash
terraform -chdir=phase2_docker/ECR apply
```

Type:

```text
yes
```

when Terraform asks for confirmation.

Terraform creates:

- The ECR repository (`adecloud/zeetafin`)
- A lifecycle policy
- A repository policy that restricts access to the current AWS account

### Get the Repository URL

```bash
terraform -chdir=phase2_docker/ECR output repository_url
```

The repository URL will have a format similar to:

```text
YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin
```

The repository can also be viewed from the AWS Console:

```text
AWS Console
    |
    v
Amazon ECR
    |
    v
Repositories
    |
    v
adecloud/zeetafin
```

### Authenticate Docker with Amazon ECR

Before pushing the images, authenticate Docker with Amazon ECR.

Run:

```bash
aws ecr get-login-password --region eu-west-1 | \
docker login --username AWS --password-stdin YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com
```

Replace `YOUR_AWS_ACCOUNT_ID` with the AWS account ID.

A successful authentication should display:

```text
Login Succeeded
```

### Tag the Docker Images

Docker images must be tagged using the ECR repository URI before they can be pushed.

Because the repository uses immutable tags, each build must use a new tag.

Tag the local images:

```bash
docker tag zeetafin-be:latest \
YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:sha-backend

docker tag zeetafin-fe:latest \
YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:sha-frontend
```

Verify the images:

```bash
docker images
```

The images should now have ECR-compatible tags.

### Push the Docker Images to ECR

Push the images:

```bash
docker push \
YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:sha-backend

docker push \
YOUR_AWS_ACCOUNT_ID.dkr.ecr.eu-west-1.amazonaws.com/adecloud/zeetafin:sha-frontend
```

Docker will upload the image layers to Amazon ECR.

A successful push should display output similar to:

```text
The push refers to repository [...]
sha-backend: digest: sha256:...
```

### Verify the Images in ECR

List the images stored in the ECR repository:

```bash
aws ecr list-images \
  --repository-name adecloud/zeetafin \
  --region eu-west-1
```

The pushed images should appear in the output.

The images can also be verified through the AWS Console:

```text
AWS Console
    |
    v
Amazon ECR
    |
    v
Repositories
    |
    v
adecloud/zeetafin
    |
    v
Images
    |
    v
sha-backend
sha-frontend
```

## EC2 Server

The `EC2/` directory contains a Terraform configuration that provisions the target server used for later deployment.

It creates:

- A VPC
- A public subnet
- An Internet Gateway
- A route table
- A security group allowing SSH (22), HTTP (80), and HTTPS (443)
- An Ubuntu 24.04 EC2 instance (`t3.medium`)

Values are defined in `EC2/terraform.tfvars`:

```hcl
aws_region         = "eu-west-1"
vpc_cidr           = "10.0.1.0/24"
public_subnet_cidr = "10.0.1.0/24"
allowed_ssh_cidr   = "0.0.0.0/0"
instance_type      = "t3.medium"
key_pair           = "ade"
```

Apply it with:

```bash
terraform -chdir=phase2_docker/EC2 init
terraform -chdir=phase2_docker/EC2 apply
```

Get the public IP address of the server:

```bash
terraform -chdir=phase2_docker/EC2 output project_instance_public_ip
```

## Evidence

### Docker Images Built Successfully

The local Docker images are visible using:

```bash
docker images
```

### Application Running in Docker

The application is running successfully inside Docker containers and can be accessed through the configured local ports.

### Images Available in Amazon ECR

The Docker images have been successfully pushed to the Amazon ECR repository.

## Expected Result

The expected workflow is:

```text
Provided Application
        |
        v
Identify Dependencies
        |
        v
Identify Application Ports
        |
        v
Identify Start Commands
        |
        v
Create Dockerfile (Backend)
        |
        v
Create Dockerfile (Frontend)
        |
        v
Create .dockerignore Files
        |
        v
Build Docker Images
        |
        v
Run Stack Locally (deploy.sh)
        |
        v
Test Application
        |
        v
Create ECR Repository (Terraform)
        |
        v
Authenticate Docker with ECR
        |
        v
Tag Docker Images
        |
        v
Push Images to ECR
        |
        v
Verify Images in ECR
```

## Success Criteria

This phase is considered successful when:

- The provided application is understood.
- The application's dependencies are identified.
- The application's required ports are identified.
- The application's start commands are identified.
- Working Dockerfiles are created for the backend and frontend.
- `.dockerignore` files are created.
- The Docker images build successfully.
- The application runs successfully inside Docker containers.
- The application can be accessed locally.
- An Amazon ECR repository is created.
- Docker successfully authenticates with Amazon ECR.
- The Docker images are tagged correctly.
- The Docker images are pushed successfully to ECR.
- The images are visible in the ECR repository.
- Evidence of the successful process is documented.

## Security Notes

The following files and credentials should not be committed to GitHub:

- AWS access keys
- AWS secret keys
- AWS session tokens
- `.env` files containing secrets
- SSH private keys
- `.pem` files
- Passwords
- API keys
- Terraform state files containing sensitive information
- Other sensitive credentials

The `.dockerignore` files also prevent sensitive configuration files from being copied into the Docker images.

AWS credentials should never be hard-coded into the Dockerfiles or application source code.

## Cleanup

To remove the local containers, network, volume, and images:

```bash
docker rm -f zeetafin-fe zeetafin-be zeetafin-db
docker network rm zeetafin-net
docker volume rm zeetafin-pgdata
docker rmi zeetafin-be:latest zeetafin-fe:latest
```

To remove the ECR repository and its images:

```bash
terraform -chdir=phase2_docker/ECR destroy
```

To remove the EC2 infrastructure:

```bash
terraform -chdir=phase2_docker/EC2 destroy
```

Type:

```text
yes
```

to confirm. This helps prevent unnecessary AWS charges.

## Conclusion

This project demonstrates how a full-stack application can be packaged into Docker containers and stored in Amazon ECR.

- **Docker** packages the backend, frontend, and database into containers.
- **Dockerfiles** define how each application image is built using multi-stage builds.
- **deploy.sh** runs the full stack locally.
- **.dockerignore** prevents unnecessary and sensitive files from being included in the images.
- **Terraform** creates the Amazon ECR repository and the EC2 server.
- **Amazon ECR** stores the Docker images in AWS.
- **AWS CLI** is used to authenticate with AWS and interact with ECR.

The final result is a working application running inside Docker containers locally and successfully pushed Docker images stored in Amazon ECR.
