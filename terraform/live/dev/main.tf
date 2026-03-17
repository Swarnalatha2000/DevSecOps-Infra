provider "aws" {
    region = "ap-south-1"
}

resource "aws_s3_bucket" "mys3" {
    bucket = "terraform-cicd"
}

resource "aws_s3_bucket_public_access_block" "buckpolicy" {
  bucket = aws_s3_bucket.mys3.id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}