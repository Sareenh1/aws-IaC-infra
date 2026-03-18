resource "aws_db_subnet_group" "main" {
  name       = "${var.environment}-rds-subnet-group"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.environment}-rds-subnet-group", Environment = var.environment }
}

resource "aws_db_instance" "mysql" {
  identifier           = "${var.environment}-mysql"
  engine               = "mysql"
  engine_version       = "8.0"
  instance_class       = var.instance_class
  allocated_storage    = var.allocated_storage
  username             = "admin"
  password             = var.db_password
  db_subnet_group_name = aws_db_subnet_group.main.name
  vpc_security_group_ids = [var.rds_sg_id]
  skip_final_snapshot  = true
  multi_az             = false
  publicly_accessible  = false
  storage_encrypted    = true

  tags = { Name = "${var.environment}-mysql", Environment = var.environment }
}
