resource "aws_ecr_repository" "app" {
  name = var.project_name

  image_tag_mutability = "MUTABLE"

  image_scanning_configuration {
    scan_on_push = true
  }

  force_delete = true
}

output "ecr_repository_url" {
  description = "Push images here."
  value       = aws_ecr_repository.app.repository_url
}
