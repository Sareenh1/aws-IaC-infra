output "endpoint" { value = aws_mq_broker.rabbitmq.instances[0].endpoints[0] }
