resource "aws_docdb_subnet_group" "main" {
  name       = "${var.environment}-docdb-subnet-group"
  subnet_ids = var.subnet_ids

  tags = { Name = "${var.environment}-docdb-subnet-group", Environment = var.environment }
}

resource "aws_docdb_cluster" "main" {
  cluster_identifier      = "${var.environment}-docdb"
  engine                  = "docdb"
  master_username         = "docdbadmin"
  master_password         = var.master_password
  db_subnet_group_name    = aws_docdb_subnet_group.main.name
  vpc_security_group_ids  = [var.docdb_sg_id]
  skip_final_snapshot     = true
  storage_encrypted       = true

  tags = { Name = "${var.environment}-docdb", Environment = var.environment }
}

resource "aws_docdb_cluster_instance" "main" {
  identifier         = "${var.environment}-docdb-instance"
  cluster_identifier = aws_docdb_cluster.main.id
  instance_class     = var.instance_class
}
