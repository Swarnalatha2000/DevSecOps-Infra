#checkov:skip=CKV2_AWS_62:Notification is not required
#checkov:skip=CKV_AWS_144:Replication will be handled separately
#checkov:skip=CKV2_AWS_64:KMS policy skip
resource "aws_s3_bucket" "this" {
    bucket = var.bucket_name
}

# versioning_configuration
resource "aws_s3_bucket_versioning" "this" {
  bucket = aws_s3_bucket.this.id
  versioning_configuration {
    status = "Enabled"
  }
}

# server side encryption configuration
resource "aws_kms_key" "this" {
  description             = "S3 KMS key"
  deletion_window_in_days = 7
  enable_key_rotation     = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "this" {
  bucket = aws_s3_bucket.this.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.this.arn
    }
  }
}

# Public access block
resource "aws_s3_bucket_public_access_block" "this" {
    bucket = aws_s3_bucket.this.id
    
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

# Logging resource
resource "aws_s3_bucket_logging" "this" {
    count  = var.enable_logging && var.log_bucket != null ? 1 : 0

    bucket = aws_s3_bucket.this.id
    depends_on = [aws_s3_bucket.log_bucket]
    target_bucket = var.log_bucket
    target_prefix = "log/"
}

resource "aws_s3_bucket_lifecycle_configuration" "this" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.this]

  bucket = aws_s3_bucket.this.id

  rule {
    id = "lifecycle-rule"
    abort_incomplete_multipart_upload {
        days_after_initiation = 7
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