resource "aws_ecr_repository" "main_ecr" {
  name                 = "python_web_application"
  image_tag_mutability = "MUTABLE"
  # Lets `terraform destroy` remove the repo even when it still holds images
  force_delete = true

  # Free basic scanning of every pushed image (results in the ECR console)
  image_scanning_configuration {
    scan_on_push = true
  }

  encryption_configuration {
    encryption_type = "AES256"
  }
}

# Keep storage (and cost) bounded: only the newest 20 images are kept
resource "aws_ecr_lifecycle_policy" "main_ecr" {
  repository = aws_ecr_repository.main_ecr.name
  policy = jsonencode({
    rules = [{
      rulePriority = 1
      description  = "Keep last 20 images"
      selection = {
        tagStatus   = "any"
        countType   = "imageCountMoreThan"
        countNumber = 20
      }
      action = { type = "expire" }
    }]
  })
}

output "repository_url" {
  value = aws_ecr_repository.main_ecr.repository_url
}
