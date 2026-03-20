variable "region"                 { default = "ap-south-1" }
variable "environment"            {}
variable "vpc_cidr"               {}
variable "public_subnet_1_cidr"   {}
variable "public_subnet_2_cidr"   {}
variable "private_subnet_1_cidr"  {}
variable "private_subnet_2_cidr"  {}
variable "node_instance_type"     {}
variable "eks_desired_size"       { type = number }
variable "eks_max_size"           { type = number }
variable "eks_min_size"           { type = number }
variable "rds_instance_class"     {}
variable "cache_node_type"        {}
variable "docdb_instance_class"   {}
variable "mq_instance_type"       {}
