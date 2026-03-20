# AWS Infrastructure as Code (IaC)

Production-grade AWS infrastructure managed with Terraform.
Three fully isolated environments: **dev**, **qat**, and **prod**.

---

## Table of Contents

- [Architecture](#architecture)
- [What Each Component Does](#what-each-component-does)
- [Repository Structure](#repository-structure)
- [Environment Comparison](#environment-comparison)
- [Prerequisites](#prerequisites)
- [One-Time Setup](#one-time-setup)
- [Deploying an Environment](#deploying-an-environment)
- [How Passwords Work](#how-passwords-work)
- [Updating Infrastructure](#updating-infrastructure)
- [Destroying an Environment](#destroying-an-environment)
- [Connecting to EKS](#connecting-to-eks)
- [Pushing Docker Images to ECR](#pushing-docker-images-to-ecr)
- [Remote State](#remote-state)
- [Common Errors and Fixes](#common-errors-and-fixes)
- [Git Workflow](#git-workflow)

---

## Architecture
```
                        Internet
                            │
                    Internet Gateway
                            │
               ┌────────────┴────────────┐
               │                         │
        Public Subnet AZ-a        Public Subnet AZ-b
        (EKS Worker Nodes)        (EKS Worker Nodes)
               │                         │
               └────────────┬────────────┘
                            │
                       NAT Gateway
                            │
               ┌────────────┴────────────┐
               │                         │
       Private Subnet AZ-a       Private Subnet AZ-b
       RDS, Redis, DocDB, MQ     RDS, Redis, DocDB, MQ
```

Each environment (dev / qat / prod) has its own:
- Isolated VPC with non-overlapping CIDRs
- Public subnets across 2 Availability Zones (EKS nodes)
- Private subnets across 2 Availability Zones (all databases)
- NAT Gateway (private resources can reach internet, internet cannot reach them)
- Security Groups (only EKS nodes can talk to databases)
- Separate Terraform state file in S3

---

## What Each Component Does

| Component | What it is | Simple explanation |
|-----------|------------|-------------------|
| VPC | Virtual Private Cloud | Your private network in AWS, like a walled office building |
| Public Subnet | Subnet with internet access | The reception area — EKS nodes live here |
| Private Subnet | Subnet without internet access | The back office — databases live here, internet cannot reach them |
| Internet Gateway | IGW | The main door of the building — allows internet in/out |
| NAT Gateway | Network Address Translation | Lets private resources call the internet for updates, but blocks inbound |
| Security Groups | Firewall rules | Only EKS nodes can talk to RDS, Redis, DocDB, MQ |
| EKS | Elastic Kubernetes Service | Runs your Docker containers / application |
| RDS | Relational Database Service | MySQL database |
| ElastiCache | Redis | In-memory cache, makes your app faster |
| DocumentDB | DocDB | MongoDB-compatible database |
| Amazon MQ | RabbitMQ | Message queue — services talk to each other through it |
| ECR | Elastic Container Registry | Private Docker image storage (like a private DockerHub) |
| S3 | Simple Storage Service | Stores Terraform state files (memory of what was built) |
| DynamoDB | NoSQL table | Prevents two people running terraform apply at the same time |
| Secrets Manager | AWS Secrets Manager | Stores passwords securely — Terraform reads them from here |

---

## Repository Structure
```
aws-IaC-infra/
│
├── terraform/
│   └── modules/                        # Reusable modules — never change per environment
│       ├── vpc/                        # VPC, subnets, IGW, NAT Gateway, route tables
│       │   ├── vpc.tf
│       │   ├── subnets.tf
│       │   ├── igw.tf
│       │   ├── nat.tf
│       │   ├── route_tables.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── security-groups/            # Firewall rules for all services
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── eks/                        # EKS cluster + node group + IAM roles
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── rds/                        # RDS MySQL + subnet group
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── elasticache/                # Redis + subnet group
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── docdb/                      # DocumentDB cluster + instance + subnet group
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       ├── mq/                         # RabbitMQ broker
│       │   ├── main.tf
│       │   ├── variables.tf
│       │   └── outputs.tf
│       └── ecr/                        # ECR Docker repository
│           ├── main.tf
│           ├── variables.tf
│           └── outputs.tf
│
└── environments/
    ├── dev/                            # Development environment (10.0.0.0/16)
    │   ├── backend.tf                  # S3 state: dev/terraform.tfstate
    │   ├── provider.tf                 # AWS provider + version lock (~> 5.0)
    │   ├── main.tf                     # Calls all modules + reads secrets
    │   ├── variables.tf                # Variable declarations
    │   └── terraform.tfvars            # Dev-specific values (sizes, CIDRs)
    │
    ├── qat/                            # QA Testing environment (10.1.0.0/16)
    │   ├── backend.tf
    │   ├── provider.tf
    │   ├── main.tf
    │   ├── variables.tf
    │   └── terraform.tfvars
    │
    └── prod/                           # Production environment (10.2.0.0/16)
        ├── backend.tf
        ├── provider.tf
        ├── main.tf
        ├── variables.tf
        └── terraform.tfvars
```

---

## Environment Comparison

| Resource | Dev | QAT | Prod |
|----------|-----|-----|------|
| VPC CIDR | 10.0.0.0/16 | 10.1.0.0/16 | 10.2.0.0/16 |
| Public Subnets | 10.0.1.0/24, 10.0.2.0/24 | 10.1.1.0/24, 10.1.2.0/24 | 10.2.1.0/24, 10.2.2.0/24 |
| Private Subnets | 10.0.3.0/24, 10.0.4.0/24 | 10.1.3.0/24, 10.1.4.0/24 | 10.2.3.0/24, 10.2.4.0/24 |
| EKS Node Type | t3.medium | t3.medium | t3.large |
| EKS Desired Nodes | 1 | 1 | 3 |
| EKS Max Nodes | 2 | 2 | 10 |
| RDS Instance | db.t3.micro | db.t3.small | db.t3.medium |
| Redis Node | cache.t3.micro | cache.t3.micro | cache.t3.small |
| DocDB Instance | db.t3.medium | db.t3.medium | db.r5.large |
| RabbitMQ | mq.t3.micro | mq.t3.micro | mq.m5.large |

---

## Prerequisites

### 1. Tools needed on the server
```bash
# Terraform
terraform version       # must be >= 1.0

# AWS CLI
aws --version           # must be >= 2.0

# Git
git --version
```

### 2. Install Terraform (if not installed)
```bash
sudo apt-get update && sudo apt-get install -y gnupg software-properties-common

wget -O- https://apt.releases.hashicorp.com/gpg | \
gpg --dearmor | \
sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg > /dev/null

echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] \
https://apt.releases.hashicorp.com $(lsb_release -cs) main" | \
sudo tee /etc/apt/sources.list.d/hashicorp.list

sudo apt update
sudo apt-get install -y terraform
```

### 3. Configure AWS credentials
```bash
aws configure
# AWS Access Key ID:     your-access-key
# AWS Secret Access Key: your-secret-key
# Default region name:   ap-south-1
# Default output format: json

# Verify
aws sts get-caller-identity
```

---

## One-Time Setup

These steps were done once and do not need to be repeated.

### Create S3 bucket for Terraform state
```bash
aws s3api create-bucket \
  --bucket sareenh-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

aws s3api put-bucket-versioning \
  --bucket sareenh-terraform-state \
  --versioning-configuration Status=Enabled

aws s3api put-bucket-encryption \
  --bucket sareenh-terraform-state \
  --server-side-encryption-configuration '{
    "Rules": [{
      "ApplyServerSideEncryptionByDefault": {
        "SSEAlgorithm": "AES256"
      }
    }]
  }'

aws s3api put-public-access-block \
  --bucket sareenh-terraform-state \
  --public-access-block-configuration \
  "BlockPublicAcls=true,IgnorePublicAcls=true,BlockPublicPolicy=true,RestrictPublicBuckets=true"
```

### Create DynamoDB table for state locking
```bash
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

### Store passwords in AWS Secrets Manager
```bash
# Dev
aws secretsmanager create-secret --name "dev/rds/password"   --secret-string "YourDevRDSPassword123!"    --region ap-south-1
aws secretsmanager create-secret --name "dev/docdb/password" --secret-string "YourDevDocDBPassword123!"  --region ap-south-1
aws secretsmanager create-secret --name "dev/mq/password"    --secret-string "YourDevRabbitMQ123!"       --region ap-south-1

# QAT
aws secretsmanager create-secret --name "qat/rds/password"   --secret-string "YourQatRDSPassword123!"    --region ap-south-1
aws secretsmanager create-secret --name "qat/docdb/password" --secret-string "YourQatDocDBPassword123!"  --region ap-south-1
aws secretsmanager create-secret --name "qat/mq/password"    --secret-string "YourQatRabbitMQ123!"       --region ap-south-1

# Prod
aws secretsmanager create-secret --name "prod/rds/password"   --secret-string "YourProdRDSPassword456!"   --region ap-south-1
aws secretsmanager create-secret --name "prod/docdb/password" --secret-string "YourProdDocDBPassword456!" --region ap-south-1
aws secretsmanager create-secret --name "prod/mq/password"    --secret-string "YourProdRabbitMQ456!"      --region ap-south-1
```

Password rules:
- `rds/password` — minimum 8 characters
- `docdb/password` — minimum 8 characters
- `mq/password` — minimum 12 characters, no special characters `@ / " `

### Update a secret (if you need to rotate a password)
```bash
aws secretsmanager update-secret \
  --secret-id "dev/rds/password" \
  --secret-string "NewPassword123!" \
  --region ap-south-1
```

---

## Deploying an Environment

### Deploy dev
```bash
cd environments/dev
terraform init      # first time only — downloads providers, connects to S3
terraform plan      # shows what will be created — no changes made yet
terraform apply     # creates the infrastructure — type yes to confirm
```

### Deploy qat
```bash
cd environments/qat
terraform init
terraform plan
terraform apply
```

### Deploy prod
```bash
cd environments/prod
terraform init
terraform plan
terraform apply
```

### What happens during apply

1. Terraform reads passwords from AWS Secrets Manager automatically
2. Creates VPC, subnets, IGW, NAT Gateway, route tables
3. Creates security groups
4. Creates EKS cluster and node group
5. Creates RDS, Redis, DocumentDB, RabbitMQ, ECR
6. Saves state to S3 bucket
7. No passwords are ever typed or stored in files

---

## How Passwords Work

Passwords are stored in AWS Secrets Manager and read automatically by Terraform. You never need to type them during `terraform apply`.
```
AWS Secrets Manager          Terraform
─────────────────────        ──────────────────────────────────
dev/rds/password      ──▶   module.rds.db_password
dev/docdb/password    ──▶   module.docdb.master_password
dev/mq/password       ──▶   module.mq.mq_password
```

To verify secrets exist:
```bash
aws secretsmanager list-secrets \
  --region ap-south-1 \
  --query 'SecretList[*].Name' \
  --output table
```

---

## Updating Infrastructure

### Example: resize RDS in dev
```bash
# Edit the value in environments/dev/terraform.tfvars
# Change: rds_instance_class = "db.t3.small"

cd environments/dev
terraform plan    # shows only the RDS change
terraform apply   # applies only what changed
```

### Example: increase EKS node count in prod
```bash
# Edit environments/prod/terraform.tfvars
# Change: eks_desired_size = 5

cd environments/prod
terraform plan
terraform apply
```

### Adding a new module

1. Create `terraform/modules/your-module/main.tf`, `variables.tf`, `outputs.tf`
2. Add the module block to `environments/<env>/main.tf`
3. Add any new variables to `environments/<env>/variables.tf` and `terraform.tfvars`
4. Run `terraform init` then `terraform apply`

---

## Destroying an Environment
```bash
cd environments/dev
terraform destroy
# Type yes to confirm
```

> WARNING: Never destroy prod without a full database backup and team approval.
> WARNING: Destroying will delete all data in RDS, Redis, and DocumentDB.

---

## Connecting to EKS
```bash
# Configure kubectl for dev
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name dev-eks

# Verify nodes are running
kubectl get nodes

# Verify all pods
kubectl get pods -A

# For qat
aws eks update-kubeconfig --region ap-south-1 --name qat-eks

# For prod
aws eks update-kubeconfig --region ap-south-1 --name prod-eks
```

---

## Pushing Docker Images to ECR
```bash
# Get your AWS account ID
ACCOUNT_ID=$(aws sts get-caller-identity --query Account --output text)
REGION="ap-south-1"
ENV="dev"   # change to qat or prod

# Login to ECR
aws ecr get-login-password --region $REGION | \
  docker login --username AWS \
  --password-stdin $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com

# Build your image
docker build -t my-app .

# Tag it
docker tag my-app:latest \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ENV-app:latest

# Push it
docker push \
  $ACCOUNT_ID.dkr.ecr.$REGION.amazonaws.com/$ENV-app:latest
```

---

## Remote State

State is stored in S3 separately per environment. This means:
- dev changes never affect qat or prod state
- Two people cannot run terraform apply at the same time (DynamoDB lock)
- State is versioned — you can roll back if something goes wrong

| Environment | S3 Key |
|-------------|--------|
| dev | `dev/terraform.tfstate` |
| qat | `qat/terraform.tfstate` |
| prod | `prod/terraform.tfstate` |
```bash
# View all state files
aws s3 ls s3://sareenh-terraform-state --recursive

# View current state of dev
cd environments/dev
terraform show

# View outputs (endpoints)
terraform output
```

---

## Common Errors and Fixes

| Error | Cause | Fix |
|-------|-------|-----|
| `Subnets must be in at least 2 AZs` | Only 1 subnet passed to EKS | Ensure `public_subnet_ids` has 2 subnets in different AZs |
| `password must be 12-250 characters` | MQ password too short | Use a password with 12+ characters in Secrets Manager |
| `autoMinorVersionUpgrade must be true` | RabbitMQ 3.13 requirement | Set `auto_minor_version_upgrade = true` in MQ module |
| `object does not have attribute vpc_id` | Missing output in module | Add the output to the module's `outputs.tf` |
| `NodeCreationFailure` | No route to internet or missing EKS subnet tags | Check route tables and add `kubernetes.io/cluster/<name>=shared` tag |
| `Error acquiring the state lock` | Another apply is running | Wait for it to finish or manually remove lock from DynamoDB |
| `Secret not found` | Secret not created in Secrets Manager | Run the `aws secretsmanager create-secret` command for that environment |
| `InvalidParameterException: Subnets` | Subnets in same AZ | Use subnets in ap-south-1a and ap-south-1b |

---

## Git Workflow
```bash
# Always create a branch for changes — never push directly to main
git checkout -b feature/your-change-name

# Make your changes to modules or environment configs
# Then stage and commit
git add .
git commit -m "feat: describe what you changed"
git push origin feature/your-change-name

# Open a Pull Request on GitHub
# Get it reviewed
# Merge to main

# After merging, pull latest and deploy
git checkout main
git pull
cd environments/dev
terraform apply
```

---

## Security Notes

- `.tfvars` files are in `.gitignore` — never committed to Git
- Passwords are stored only in AWS Secrets Manager — never in code or files
- All databases are in private subnets — not reachable from the internet
- Security groups allow only EKS nodes to connect to databases
- ECR has `scan_on_push = true` — Docker images scanned for vulnerabilities automatically
- RDS and DocumentDB have `storage_encrypted = true`
- S3 state bucket has AES256 encryption and public access fully blocked
- DynamoDB lock table prevents concurrent state corruption

---

## Infrastructure Details

| Resource | Value |
|----------|-------|
| AWS Region | ap-south-1 (Mumbai) |
| State S3 Bucket | sareenh-terraform-state |
| State Lock Table | terraform-locks |
| Terraform Version | >= 1.0 |
| AWS Provider Version | ~> 5.0 |
| GitHub Repo | https://github.com/Sareenh1/aws-IaC-infra |
