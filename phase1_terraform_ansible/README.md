# AWS EC2 Infrastructure with Terraform and Ansible

## Project Overview

This project provisions an AWS EC2 server using Terraform and configures the server using Ansible.

Terraform is responsible for creating the AWS infrastructure, while Ansible connects to the EC2 instance and configures the server.

The server is configured to:

- Update the Ubuntu system
- Install Docker
- Start and enable Docker
- Test Docker
- Run an Nginx container
- Verify that Nginx is working on port 80

## Architecture

```text
                    AWS
                     |
                     v
                    VPC
                     |
                  Subnet
                     |
              Internet Gateway
                     |
                     v
              Security Group
                |          |
             SSH :22    HTTP :80
                |          |
                +----+-----+
                     |
                     v
                 EC2 Ubuntu
                     |
                  Ansible
                     |
                 +---+---+
                 |       |
              Docker   Nginx
                        Container
                 |       |
                 +---+---+
                     |
                  Port 80
                     |
                     v
                Web Browser
```

## Project Structure

```text
.
├── infrastructure/
│   ├── main.tf
│   ├── variables.tf
│   └── outputs.tf
│
├── ansible/
│   ├── inventory.ini
│   └── playbook.yml
│
├── screenshots/
│   ├── ec2-running.png
│   ├── ansible-success.png
│   └── nginx-working.png
│
└── README.md
```

## Technologies Used

- AWS
- Terraform
- Ansible
- Ubuntu
- Docker
- Nginx

## Prerequisites

The following tools are required:

- Terraform
- Ansible
- AWS CLI
- Git

You also need:

- An AWS account
- AWS credentials
- An EC2 SSH key pair
- SSH private key (`.pem`)

## Check Installed Tools

```bash
terraform --version
ansible --version
aws --version
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

Do not upload AWS credentials or private keys to GitHub.

## Terraform

Terraform creates the AWS infrastructure required for the EC2 server.

### Initialize Terraform

```bash
terraform -chdir=infrastructure init
```

### Validate Terraform Configuration

```bash
terraform -chdir=infrastructure validate
```

A successful validation should show:

```text
Success! The configuration is valid.
```

### Review the Terraform Plan

```bash
terraform -chdir=infrastructure plan
```

This shows which AWS resources Terraform will create.

### Create the Infrastructure

```bash
terraform -chdir=infrastructure apply
```

Type:

```text
yes
```

when Terraform asks for confirmation.

Terraform will create:

- VPC
- Subnet
- Internet Gateway
- Route Table
- Security Group
- EC2 Instance

### Get the EC2 Public IP

```bash
terraform -chdir=infrastructure output
```

Use the EC2 public IP address in the Ansible inventory.

## Ansible

Ansible is used to configure the EC2 instance after Terraform creates it.

### Configure the Inventory

Edit:

```text
ansible/inventory.ini
```

Example:

```ini
[workers]
ec2 ansible_host=YOUR_EC2_PUBLIC_IP ansible_user=ubuntu ansible_ssh_private_key_file=~/.ssh/YOUR_KEY.pem
```

Replace:

- `YOUR_EC2_PUBLIC_IP` with the public IP of your EC2 instance
- `YOUR_KEY.pem` with the name of your SSH private key

### Install the Docker Collection

The playbook uses the `community.docker` Ansible collection.

Install it with:

```bash
ansible-galaxy collection install community.docker
```

### Test the Ansible Connection

```bash
ansible workers -i ansible/inventory.ini -m ping
```

A successful result should contain:

```text
SUCCESS
"ping": "pong"

### Run the Ansible Playbook

```bash
ansible-playbook -i ansible/inventory.ini ansible/playbook.yml
```

The playbook performs the following tasks:

2. Install Docker
3. Start and enable Docker
4. Test Docker using the `hello-world` image
5. Run an Nginx container
6. Expose Nginx on port 80
7. Verify that Nginx responds successfully

A successful playbook run should finish with:

```text
unreachable=0
```

## Verify Docker

The playbook tests Docker by running the `hello-world` container.

```bash
```

A successful Docker test confirms that Docker is installed and working correctly.

## Verify Nginx

After Ansible finishes successfully, open the following URL in a web browser:

```text
http://YOUR_EC2_PUBLIC_IP
```

The Nginx welcome page should be displayed.

## Security Group

The EC2 security group allows the following inbound traffic:

| Protocol | Port | Purpose |
|----------|------|---------|
| TCP | 22 | SSH |
| TCP | 80 | HTTP / Nginx |

SSH access should preferably be restricted to your own IP address.

Port 80 is opened so that the Nginx server can be accessed from a web browser.

## Evidence

### EC2 Instance Running

The AWS EC2 console shows that the EC2 instance was successfully created and is running.

![EC2 Instance Running](screenshots/ec2-running.png)

### Ansible Configuration Successful

The Ansible playbook completed successfully with no failed or unreachable hosts.

![Ansible Successful](screenshots/ansible-success.png)

### Nginx Working

The Nginx container is running on the EC2 instance and can be accessed through port 80.

![Nginx Working](screenshots/nginx-working.png)

## Expected Result

The expected workflow is:

```text
Terraform
    |
    v
Create AWS Infrastructure
    |
    v
Create EC2 Instance
    |
    v
Ansible Connects Through SSH
    |
    v
Update Ubuntu
    |
    v
Install Docker
    |
    v
Start Docker
    |
    v
Run Nginx Container
    |
    v
Nginx Listens on Port 80
    |
    v
Browser Displays Nginx Page
```

## Cleanup

To remove the AWS resources after completing the project:

```bash
terraform -chdir=infrastructure destroy
```

Type:

```text
yes
```

to confirm.

This helps prevent unnecessary AWS charges.

## Security Notes

The following files and credentials should not be committed to GitHub:

- AWS access keys
- AWS secret keys
- SSH private keys
- `.pem` files
- Terraform state files containing sensitive information
- Passwords
- Other secrets

## Conclusion

This project demonstrates Infrastructure as Code and server configuration using Terraform and Ansible.

- **Terraform** creates and manages the AWS infrastructure.
- **Ansible** configures the EC2 server.
- **Docker** runs the Nginx application.
- **Nginx** provides the web server.
- **AWS Security Groups** control network access.

The final result is an AWS EC2 server provisioned by Terraform and successfully configured by Ansible.
docker run --rm hello-world
failed=0
1. Update the Ubuntu server

