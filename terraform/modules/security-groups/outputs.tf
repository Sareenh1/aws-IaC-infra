output "eks_nodes_sg_id" {
  value = aws_security_group.eks_nodes.id
}

output "rds_sg_id" {
  value = aws_security_group.rds.id
}

output "redis_sg_id" {
  value = aws_security_group.redis.id
}

output "docdb_sg_id" {
  value = aws_security_group.docdb.id
}

output "rabbitmq_sg_id" {
  value = aws_security_group.rabbitmq.id
}
