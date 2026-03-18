# AWS Infrastructure as Code (IaC)

Production-grade AWS infrastructure managed with Terraform.
Supports three isolated environments: **dev**, **qat**, and **prod**.

---

## Architecture Overview
```
Internet
    │
    ▼
Internet Gateway
    │
    ▼
Public Subnets (AZ-a, AZ-b)     ← EKS Worker Nodes
    │
    ▼
NAT Gateway
    │
    ▼
Private Subnets (AZ-a, AZ-b)    ← RDS, Redis, DocDB, RabbitMQ
```

Each environment gets its own:
- Isolated VPC with non-overlapping CIDRs
- Public + private subnets across 2 Availability Zones
- EKS cluster with managed node groups
- RDS MySQL, ElastiCache Redis, DocumentDB, RabbitMQ
- ECR repository for Docker images
- Security groups (least-privilege, services only accessible from EKS nodes)
- Remote state in S3 with DynamoDB locking

---

## Repository Structure
```
aws-IaC-infra/
├── terraform/
│   └── modules/                  # Reusable modules (never edit per-env)
│       ├── vpc/                  # VPC, subnets, IGW, NAT, route tables
│       ├── security-groups/      # SGs for EKS, RDS, Redis, DocDB, MQ
│       ├── eks/                  # EKS cluster + managed node group + IAM
│       ├── rds/                  # RDS MySQL + subnet group
│       ├── elasticache/          # Redis + subnet group
│       ├── docdb/                # DocumentDB cluster + instance
│       ├── mq/                   # RabbitMQ broker
│       └── ecr/                  # ECR repository
│
└── environments/
    ├── dev/                      # Development (10.0.0.0/16)
    │   ├── backend.tf            # S3 state: dev/terraform.tfstate
    │   ├── provider.tf           # AWS provider + version lock
    │   ├── main.tf               # Calls all modules
    │   ├── variables.tf          # Variable declarations
    │   └── terraform.tfvars      # Dev-specific values (sizes, CIDRs)
    ├── qat/                      # QA Testing (10.1.0.0/16)
    └── prod/                     # Production (10.2.0.0/16)
```

---

## Environment Comparison

| Resource            | Dev              | QAT              | Prod              |
|---------------------|------------------|------------------|-------------------|
| VPC CIDR            | 10.0.0.0/16      | 10.1.0.0/16      | 10.2.0.0/16       |
| EKS Nodes           | t3.medium (1)    | t3.medium (1)    | t3.large (3)      |
| EKS Max Nodes       | 2                | 2                | 10                |
| RDS Instance        | db.t3.micro      | db.t3.small      | db.t3.medium      |
| Redis Node          | cache.t3.micro   | cache.t3.micro   | cache.t3.small    |
| DocDB Instance      | db.t3.medium     | db.t3.medium     | db.r5.large       |
| RabbitMQ            | mq.t3.micro      | mq.t3.micro      | mq.m5.large       |

---

## Prerequisites

### Tools required on your machine
```bash
# Terraform
terraform version    # should be >= 1.0

# AWS CLI
aws --version        # should be >= 2.0

# Git
git --version
```

### AWS credentials
```bash
aws configure
# Enter: Access Key ID, Secret Access Key, region (ap-south-1), output (json)

# Verify
aws sts get-caller-identity
```

---

## One-time Setup (already done)

These resources were created once and are shared across all environments:
```bash
# S3 bucket for remote state
aws s3api create-bucket \
  --bucket sareenh-terraform-state \
  --region ap-south-1 \
  --create-bucket-configuration LocationConstraint=ap-south-1

# Enable versioning
aws s3api put-bucket-versioning \
  --bucket sareenh-terraform-state \
  --versioning-configuration Status=Enabled

# DynamoDB for state locking
aws dynamodb create-table \
  --table-name terraform-locks \
  --attribute-definitions AttributeName=LockID,AttributeType=S \
  --key-schema AttributeName=LockID,KeyType=HASH \
  --billing-mode PAY_PER_REQUEST \
  --region ap-south-1
```

---

## Deploying an Environment

### Step 1 — Set passwords as environment variables (recommended)
```bash
export TF_VAR_db_password="YourStrongPassword123!"
export TF_VAR_docdb_password="YourDocDBPassword123!"
export TF_VAR_mq_password="YourRabbitMQPassword123!"
```

Password rules:
- `db_password`: min 8 characters
- `docdb_password`: min 8 characters
- `mq_password`: min 12 characters, no special chars `@ / " `

### Step 2 — Initialize and apply
```bash
cd environments/dev    # or qat / prod
terraform init         # downloads providers, connects to S3 backend
terraform plan         # shows what will be created (no changes made)
terraform apply        # creates the infrastructure (type 'yes' to confirm)
```

### Step 3 — Verify
```bash
terraform show         # shows current state
terraform output       # shows output values (endpoints, etc.)
```

---

## Making Changes

### Change a single resource (example: resize RDS)
```bash
# Edit environments/dev/terraform.tfvars
# Change: rds_instance_class = "db.t3.small"

cd environments/dev
terraform plan    # shows only the RDS change
terraform apply   # applies only what changed
```

### Add a new module
1. Create the module in `terraform/modules/your-module/`
2. Add `main.tf`, `variables.tf`, `outputs.tf`
3. Reference it in `environments/<env>/main.tf`
4. Add any new variables to `environments/<env>/variables.tf` and `terraform.tfvars`

---

## Destroying an Environment
```bash
cd environments/dev
terraform destroy \
  -var="db_password=YourPass" \
  -var="docdb_password=YourPass" \
  -var="mq_password=YourRabbitMQPass"
# Type 'yes' to confirm
```

> ⚠️ Never run `terraform destroy` on prod without a full backup and team approval.

---

## Remote State

State is stored in S3 with per-environment keys:

| Environment | S3 Key                        |
|-------------|-------------------------------|
| dev         | `dev/terraform.tfstate`       |
| qat         | `qat/terraform.tfstate`       |
| prod        | `prod/terraform.tfstate`      |

DynamoDB table `terraform-locks` prevents two people from running `terraform apply` at the same time.

To see current state:
```bash
aws s3 ls s3://sareenh-terraform-state --recursive
```

---

## Security Notes

- `.tfvars` files are in `.gitignore` — passwords are never committed to Git
- All databases are in **private subnets** — not reachable from the internet
- Security groups only allow traffic from EKS nodes to databases
- ECR has `scan_on_push = true` — Docker images are scanned for vulnerabilities
- RDS and DocDB have `storage_encrypted = true`
- S3 state bucket has encryption and public access blocked

---

## Connecting to the EKS Cluster

After deployment, configure kubectl:
```bash
aws eks update-kubeconfig \
  --region ap-south-1 \
  --name dev-eks

# Verify
kubectl get nodes
kubectl get pods -A
```

---

## Pushing Docker Images to ECR
```bash
# Get ECR login token
aws ecr get-login-password --region ap-south-1 | \
  docker login --username AWS \
  --password-stdin <account-id>.dkr.ecr.ap-south-1.amazonaws.com

# Tag and push
docker tag my-app:latest <account-id>.dkr.ecr.ap-south-1.amazonaws.com/dev-app:latest
docker push <account-id>.dkr.ecr.ap-south-1.amazonaws.com/dev-app:latest
```

---

## Common Issues

| Error | Cause | Fix |
|-------|-------|-----|
| `Subnets must be in at least 2 AZs` | Only 1 subnet passed to EKS | Ensure `public_subnet_ids` returns 2 subnets |
| `password must be 12-250 characters` | MQ password too short | Use a password with 12+ characters |
| `autoMinorVersionUpgrade must be true` | RabbitMQ 3.13 requirement | Set `auto_minor_version_upgrade = true` |
| `This object does not have attribute vpc_id` | Missing output in module | Add the output to the module's `outputs.tf` |
| `NodeCreationFailure` | Subnet missing EKS tags or no route to internet | Add `kubernetes.io/cluster/<name>=shared` tag and check route tables |

---

## Git Workflow
```bash
# Always work on a branch for changes
git checkout -b feature/add-alb-module

# Make changes, then
git add .
git commit -m "feat: add ALB ingress module"
git push origin feature/add-alb-module

# Open a PR on GitHub, review, then merge to main
# Never push directly to main for prod changes
```

---

## Maintainers

- **Repo**: https://github.com/Sareenh1/aws-IaC-infra
- **Region**: ap-south-1 (Mumbai)
- **State Bucket**: sareenh-terraform-state
- **Lock Table**: terraform-locks
