# ── Read secrets from AWS Secrets Manager ──
data "aws_secretsmanager_secret_version" "db_password" {
  secret_id = "${var.environment}/rds/password"
}

data "aws_secretsmanager_secret_version" "docdb_password" {
  secret_id = "${var.environment}/docdb/password"
}

data "aws_secretsmanager_secret_version" "mq_password" {
  secret_id = "${var.environment}/mq/password"
}

# ── Modules ──
module "vpc" {
  source                = "../../terraform/modules/vpc"
  environment           = var.environment
  region                = var.region
  vpc_cidr              = var.vpc_cidr
  public_subnet_1_cidr  = var.public_subnet_1_cidr
  public_subnet_2_cidr  = var.public_subnet_2_cidr
  private_subnet_1_cidr = var.private_subnet_1_cidr
  private_subnet_2_cidr = var.private_subnet_2_cidr
}

module "security_groups" {
  source      = "../../terraform/modules/security-groups"
  environment = var.environment
  vpc_id      = module.vpc.vpc_id
  vpc_cidr    = var.vpc_cidr
}

module "eks" {
  source             = "../../terraform/modules/eks"
  environment        = var.environment
  cluster_name       = "${var.environment}-eks"
  vpc_id             = module.vpc.vpc_id
  subnet_ids         = module.vpc.public_subnet_ids
  node_instance_type = var.node_instance_type
  desired_size       = var.eks_desired_size
  max_size           = var.eks_max_size
  min_size           = var.eks_min_size
  eks_nodes_sg_id    = module.security_groups.eks_nodes_sg_id
}

module "rds" {
  source         = "../../terraform/modules/rds"
  environment    = var.environment
  subnet_ids     = module.vpc.private_subnet_ids
  rds_sg_id      = module.security_groups.rds_sg_id
  db_password    = data.aws_secretsmanager_secret_version.db_password.secret_string
  instance_class = var.rds_instance_class
}

module "redis" {
  source      = "../../terraform/modules/elasticache"
  environment = var.environment
  subnet_ids  = module.vpc.private_subnet_ids
  redis_sg_id = module.security_groups.redis_sg_id
  node_type   = var.cache_node_type
}

module "docdb" {
  source          = "../../terraform/modules/docdb"
  environment     = var.environment
  subnet_ids      = module.vpc.private_subnet_ids
  docdb_sg_id     = module.security_groups.docdb_sg_id
  master_password = data.aws_secretsmanager_secret_version.docdb_password.secret_string
  instance_class  = var.docdb_instance_class
}

module "mq" {
  source         = "../../terraform/modules/mq"
  environment    = var.environment
  subnet_ids     = module.vpc.private_subnet_ids
  rabbitmq_sg_id = module.security_groups.rabbitmq_sg_id
  mq_password    = data.aws_secretsmanager_secret_version.mq_password.secret_string
  instance_type  = var.mq_instance_type
}

module "ecr" {
  source      = "../../terraform/modules/ecr"
  environment = var.environment
}
