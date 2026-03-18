variable "environment" {}
variable "subnet_ids" { type = list(string) }
variable "redis_sg_id" {}
variable "node_type" { default = "cache.t3.micro" }
