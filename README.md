# AWS Infrastructure as Code

## Structure
```
terraform/modules/   # Reusable modules
environments/
  dev/               # Development (10.0.0.0/16)
  qat/               # QA Testing  (10.1.0.0/16)
  prod/              # Production  (10.2.0.0/16)
```

## Deploy an environment
```bash
cd environments/dev
terraform init
terraform plan -var="db_password=xxx" -var="docdb_password=xxx" -var="mq_password=xxx"
terraform apply -var="db_password=xxx" -var="docdb_password=xxx" -var="mq_password=xxx"
```
