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

resource "aws_s3_bucket_versioning" "myver" {
  bucket = aws_s3_bucket.mys3.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.myver]

  bucket = aws_s3_bucket.mys3.id

  rule {

    filter {
      prefix = ""
    }

    noncurrent_version_expiration {
      noncurrent_days = 90
    }

    noncurrent_version_transition {
      noncurrent_days = 30
      storage_class   = "STANDARD_IA"
    }

    noncurrent_version_transition {
      noncurrent_days = 60
      storage_class   = "GLACIER"
    }

    status = "Enabled"
  }
}