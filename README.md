# AWS DevOps Project

## Project Overview

This project demonstrates a complete DevOps workflow for deploying an application to AWS.

The project is divided into three phases:

- Phase 1: Provision AWS Infrastructure with Terraform and Ansible
- Phase 2: Containerize the Application and Push to Amazon ECR
- Phase 3: Deploy the Application Using GitHub Actions

The final goal is to demonstrate the following workflow:

```text
Application
     |
     v
Docker Container
     |
     v
Docker Image
     |
     v
Amazon ECR
     |
     v
GitHub Actions
     |
     v
AWS EC2
     |
     v
Application Running
```

---

# Project Phases

## Phase 1 - AWS Infrastructure with Terraform and Ansible

### Status

**Completed**

### Objective

Provision an AWS EC2 server using Terraform and configure the server using Ansible.

### Requirements

The following AWS infrastructure is created using Terraform:

- VPC
- Subnet
- Security Group
- EC2 Instance

Terraform variables are used to make the infrastructure configurable.

Ansible is then used to connect to the EC2 instance and configure the server.

### Ansible Configuration

Ansible performs the following tasks:

- Update the Ubuntu server
- Install Docker
- Start Docker
- Enable Docker to start automatically
- Test Docker
- Run an Nginx container
- Verify that the server is working

### Technologies

- AWS EC2
- Terraform
- Ansible
- Ubuntu
- Docker
- Nginx

### Expected Result

```text
Terraform
    |
    v
AWS Infrastructure
    |
    v
EC2 Instance
    |
    v
Ansible
    |
    v
Docker
    |
    v
Nginx
    |
    v
Working Server
```

### Phase 1 Deliverables

- Terraform configuration files
- Ansible playbook
- AWS EC2 instance
- VPC
- Subnet
- Security Group
- Docker installation
- Nginx container
- README documentation
- Screenshot of EC2 instance running
- Screenshot/evidence of successful Ansible configuration

### Phase 1 Structure

```text
phase-1/
├── infrastructure/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── ansible/
│   ├── inventory.ini
│   └── playbook.yml
│
└── README.md
```

---

# Phase 2 - Application Containerization and Amazon ECR

### Status

**Ongoing**

### Objective

Containerize the application provided for the project, test it locally, and push the Docker image to Amazon Elastic Container Registry (ECR).

### Requirements

The application will first be reviewed to identify:

- Application dependencies
- Required port
- Application start command

A Dockerfile will then be created to package the application into a Docker image.

A `.dockerignore` file will also be created to prevent unnecessary files from being included in the Docker image.

### Planned Tasks

- Clone and understand the provided application
- Identify application dependencies
- Identify the required application port
- Identify the application start command
- Create a Dockerfile
- Create a `.dockerignore` file
- Build the Docker image locally
- Run the container locally
- Verify that the application works
- Create an Amazon ECR repository
- Authenticate Docker with Amazon ECR
- Tag the Docker image
- Push the image to Amazon ECR
- Verify that the image is available in ECR
- Document the containerization process

### Expected Workflow

```text
Provided Application
        |
        v
    Dockerfile
        |
        v
   Docker Build
        |
        v
   Docker Image
        |
        v
 Run Container Locally
        |
        v
 Test Application
        |
        v
 Amazon ECR
        |
        v
 Push Docker Image
```

### Expected Deliverables

- Provided application code
- Dockerfile
- `.dockerignore`
- Docker image
- Amazon ECR repository
- Successfully pushed image
- README documentation
- Evidence that the application runs successfully in a container
- Evidence that the Docker image has been pushed to ECR

### Success Criteria

The completed Phase 2 should demonstrate:

```text
Provided Application
        |
        v
Docker Container
        |
        v
Docker Image
        |
        v
Amazon ECR
```

### Phase 2 Structure

```text
phase-2/
├── application/
├── Dockerfile
├── .dockerignore
└── README.md
```

---

# Phase 3 - CI/CD with GitHub Actions

### Status

**Ongoing**

### Objective

Create a GitHub Actions CI/CD pipeline that automatically builds the application's Docker image, pushes it to Amazon ECR, and deploys the application to the AWS EC2 infrastructure created in Phase 1.

### Requirements

The Phase 3 pipeline will use the application and infrastructure created during the previous phases.

GitHub Actions will be configured to:

- Checkout the application code
- Build the Docker image
- Authenticate with AWS
- Push the Docker image to Amazon ECR
- Connect to the EC2 server
- Deploy the new container
- Store credentials securely using GitHub Secrets
- Configure the EC2 server to run the container
- Replace the old application container when a new version is deployed
- Trigger the pipeline when changes are pushed to the appropriate GitHub branch
- Verify that the application is accessible after deployment
- Document the CI/CD process

### Planned GitHub Actions Workflow

```text
Developer pushes code
        |
        v
        |
        v
 GitHub Actions
        |
        v
Build Docker Image

        |
        v

 Authenticate with AWS
        |
        v
    Push to ECR

        |
        v

   Connect to EC2
        |
        v
 Pull New Image
        |
        v
Stop Old Container
        |
        v

Start New Container
        |
        v
Application Running
```

### GitHub Secrets

Sensitive credentials will be stored using GitHub Secrets instead of being hard-coded in the workflow.

Examples include:

- AWS credentials
- AWS region
- ECR repository information
- EC2 deployment credentials

No secrets should be committed to the GitHub repository.

### Expected Deliverables

- GitHub repository
- Dockerfile
- `.dockerignore`
- GitHub Actions workflow
- Amazon ECR repository
- Docker image in ECR
- EC2 deployment
- GitHub Secrets configured
- README documentation
- Screenshot/evidence of successful GitHub Actions workflow
- Screenshot/evidence of the application running on AWS

### Success Criteria

The completed Phase 3 should demonstrate that when an application update is pushed to GitHub, GitHub Actions can automatically:

1. Build the new Docker image
2. Authenticate with AWS
3. Push the image to Amazon ECR
4. Connect to the EC2 server
5. Pull the new image
6. Replace the old application container
7. Start the updated application
8. Make the updated application accessible

---

# Complete Project Workflow

When all three phases are completed, the overall architecture will be:

```text
                    Developer
                        |
                        | Push Code
                        v
                    GitHub
                        |
                        v
                 GitHub Actions
                        |
                        | Build
                        v
                  Docker Image
                        |
                        | Push
                        v
                  Amazon ECR
                        |
                        | Pull
                        v
                    AWS EC2
                        |
                        v
                Docker Container
                        |
                        v
                  Application
```

The infrastructure will be provisioned and configured before the application deployment pipeline runs.

```text
             PHASE 1
                 |
                 v
       Terraform + Ansible
                 |
                 v
            AWS EC2
                 |
                 |
             PHASE 2
                 |
                 v
       Docker + Amazon ECR
                 |
                 |
             PHASE 3
                 |
                 v
         GitHub Actions
                 |
                 v
        Automated Deployment
                 |
                 v
          Application on EC2
```

# Current Project Status

| Phase | Description | Status |
|-------|-------------|--------|
| Phase 1 | AWS Infrastructure with Terraform and Ansible | Completed |
| Phase 2 | Application Containerization and Amazon ECR | Ongoing |
| Phase 3 | CI/CD with GitHub Actions | Ongoing |

# Technologies Used

## Infrastructure

- AWS
- Terraform
- Ansible
- Ubuntu
- Amazon EC2
- VPC
- Security Groups

## Containerization

- Docker
- Amazon ECR

## CI/CD

- GitHub
- GitHub Actions

## Application

- Application provided for the project
- Nginx used during Phase 1 server testing

# Repository Structure

The repository will evolve as each phase is completed.

```text
.
├── phase-1/
│   ├── infrastructure/
│   │   ├── main.tf
│   │   ├── variables.tf
│   │   └── outputs.tf
│   │
│   ├── ansible/
│   │   ├── inventory.ini
│   │   └── playbook.yml
│   │
│   └── README.md
│
├── phase-2/
│   ├── application/
│   ├── Dockerfile
│   ├── .dockerignore
│   └── README.md
│
├── phase-3/
│   ├── .github/
│   │   └── workflows/
│   │       └── deploy.yml
│   │
│   └── README.md
│
└── README.md
```

# Security

Sensitive information must never be committed to the repository.

The following should not be pushed to GitHub:

- AWS Access Keys
- AWS Secret Keys
- SSH private keys
- `.pem` files
- Passwords
- API keys
- Terraform state files containing sensitive information
- GitHub tokens
- Other credentials or secrets

GitHub Secrets should be used for sensitive CI/CD credentials.

# Phase 1 Evidence

Screenshots and evidence for Phase 1 should be stored in the appropriate project directory.

Examples include:

- EC2 instance running
- Terraform successfully creating infrastructure
- Ansible successfully connecting to EC2
- Docker successfully installed
- Nginx successfully running

# Phase 2 Evidence

Evidence will be added as Phase 2 is completed.

Planned evidence includes:

- Application running locally
- Docker image successfully built
- Docker container running
- Application accessible from the container
- Amazon ECR repository created
- Docker image successfully pushed to ECR

# Phase 3 Evidence

Evidence will be added as Phase 3 is completed.

Planned evidence includes:

- GitHub Actions workflow
- Successful Docker build
- Successful ECR push
- Successful EC2 deployment
- Application running on AWS
- Updated application successfully deployed after a GitHub push

# Final Expected Result

When all three phases are complete, the project should demonstrate a complete automated deployment workflow:

```text
Developer
    |
    | Push application changes
    v
GitHub
    |
    v
GitHub Actions
    |
    +--------------------+
    |                    |
    v                    v
Build Docker Image    Authenticate AWS
    |                    |
    +---------+----------+
              |
              v
        Amazon ECR
              |
              | Pull Image
              v
          AWS EC2
              |
              v
      Docker Container
              |
              v
        Application
              |
              v
       Application
        Accessible
```

# Project Goal

The overall goal of this project is to demonstrate the ability to:

- Provision cloud infrastructure using Terraform
- Configure servers using Ansible
- Containerize applications using Docker
- Store container images using Amazon ECR
- Build automated CI/CD pipelines using GitHub Actions
- Deploy applications automatically to AWS EC2
- Manage application updates through an automated deployment process

# Status

Phase 1 is completed.

Phase 2 is currently ongoing and will be updated as the containerization and ECR deployment work is completed.

Phase 3 is currently ongoing and will be updated when the GitHub Actions CI/CD pipeline is implemented.

