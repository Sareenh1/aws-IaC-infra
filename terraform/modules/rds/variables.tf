variable "environment" {}
variable "subnet_ids" { type = list(string) }
variable "rds_sg_id" {}
variable "db_password" { sensitive = true }
variable "instance_class" { default = "db.t3.micro" }
variable "allocated_storage" { default = 20 }
