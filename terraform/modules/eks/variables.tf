variable "environment" {}
variable "cluster_name" {}
variable "vpc_id" {}
variable "subnet_ids" { type = list(string) }
variable "node_instance_type" { default = "t3.medium" }
variable "desired_size" { default = 1 }
variable "max_size" { default = 2 }
variable "min_size" { default = 1 }
variable "eks_nodes_sg_id" {}
