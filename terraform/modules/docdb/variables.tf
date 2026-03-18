variable "environment" {}
variable "subnet_ids" { type = list(string) }
variable "docdb_sg_id" {}
variable "master_password" { sensitive = true }
variable "instance_class" { default = "db.t3.medium" }
