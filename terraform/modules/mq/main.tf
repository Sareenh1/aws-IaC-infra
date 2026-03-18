resource "aws_mq_broker" "rabbitmq" {
  broker_name             = "${var.environment}-rabbitmq"
  engine_type             = "RabbitMQ"
  engine_version          = "3.13"
  host_instance_type      = var.instance_type
  deployment_mode         = "SINGLE_INSTANCE"
  publicly_accessible     = false
  subnet_ids              = [var.subnet_ids[0]]
  security_groups         = [var.rabbitmq_sg_id]

  user {
    username = "mqadmin"
    password = var.mq_password
  }

  tags = { Name = "${var.environment}-rabbitmq", Environment = var.environment }
}
