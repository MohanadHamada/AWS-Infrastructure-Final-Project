/*
resource "aws_s3_bucket" "terraform_state" {
  bucket = "terraform-infra-state-bucket-1561"
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_s3_bucket_versioning" "enable_versioning" {
  bucket = aws_s3_bucket.terraform_state.id
  versioning_configuration {
    status = "Enabled"
  }
  lifecycle {
    prevent_destroy = true
  }
}
resource "aws_dynamodb_table" "name" {
  name = "terraform-infra-state-dynamodb-table"
  billing_mode = "PAY_PER_REQUEST"
  hash_key = "LockID"
  attribute {
    name = "LockID"
    type = "S"
  }
  lifecycle {
    prevent_destroy = true
  }
}
*/

/*
- After applying this configuration, if you want to remove the resources from the state file without deleting them from AWS (lifecycle{prevent_destroy = true} whole destroy proccess stop ,not skip to other and keep remote backend)
, you can use the following commands:

terraform state rm aws_s3_bucket.terraform_state
terraform state rm aws_s3_bucket_versioning.enable_versioning
terraform state rm aws_dynamodb_table.name

- Comment the resource blocks in this file and run terraform apply to avoid recreating them.

- If you want to re-import these resources back into the state file to edit or destroy all resourses which created, you can use the following commands:

terraform import aws_s3_bucket.terraform_state terraform-infra-state-bucket-1561
terraform import aws_s3_bucket_versioning.enable_versioning terraform-infra-state-bucket-1561
terraform import aws_dynamodb_table.name terraform-infra-state-dynamodb-table

*/

terraform {
  backend "s3" {
    bucket         = "terraform-infra-state-bucket-1561"
    key            = "dev/terraform.tfstate"
    region         = "us-east-1"
    dynamodb_table = "terraform-infra-state-dynamodb-table"
    encrypt        = true
    profile        = "default"
  }
}