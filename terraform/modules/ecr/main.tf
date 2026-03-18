resource "aws_ecr_repository" "main" {
  name                 = "${var.environment}-${var.repo_name}"
  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  tags = { Name = "${var.environment}-${var.repo_name}", Environment = var.environment }
}
