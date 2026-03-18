variable "environment" {}
variable "subnet_ids" { type = list(string) }
variable "rabbitmq_sg_id" {}
variable "mq_password" { sensitive = true }
variable "instance_type" { default = "mq.t3.micro" }
