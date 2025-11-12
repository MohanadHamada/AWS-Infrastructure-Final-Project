resource "aws_ecr_repository" "repo" {
  name                 = var.repo_name
  image_tag_mutability = "MUTABLE"

  encryption_configuration {
    encryption_type = "AES256"
  }

  tags = { Name = var.repo_name }
}

resource "aws_ecr_lifecycle_policy" "repo_policy" {
  repository = aws_ecr_repository.repo.name

  policy = jsonencode({
    rules = [{
      rulePriority = 1,
      description  = "expire untagged after 30 days",
      selection    = {
        tagStatus     = "untagged",
        countType     = "sinceImagePushed",
        countNumber   = 30,
        countUnit     = "days"
      },
      action = { type = "expire" }
    }]
  })
}
