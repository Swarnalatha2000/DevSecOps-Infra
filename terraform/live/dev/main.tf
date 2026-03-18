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

# Log bucket and logs were enabled
resource "aws_s3_bucket" "logs" {
  bucket = "my-app-s3-logs"
}

resource "aws_s3_bucket_logging" "log_config" {
  bucket        = aws_s3_bucket.mys3.id
  target_bucket = aws_s3_bucket.logs.id
  target_prefix = "access-logs/"
}

resource "aws_s3_bucket_versioning" "myver" {
  bucket = aws_s3_bucket.mys3.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_versioning" "destver" {
  bucket = aws_s3_bucket.destination.id
  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.myver]

  bucket = aws_s3_bucket.mys3.id

  rule {
    id = "default-lifecycle-rule"

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

# Enabling the notification event through SNS
resource "aws_sns_topic" "mysns" {
  name = "my-topic"
}

data "aws_iam_policy_document" "sns_s3_publish" {
  statement {
    sid = "AllowS3Publish"
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = [
      "sns:Publish"
    ]

    resources = [
      aws_sns_topic.mysns.arn
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.mys3.arn]   # your S3 bucket
    }
  }
}

resource "aws_sns_topic_policy" "sns_policy" {
  arn    = aws_sns_topic.mysns.arn
  policy = data.aws_iam_policy_document.sns_s3_publish.json
}

resource "aws_s3_bucket_notification" "sns_trigger" {
  bucket = aws_s3_bucket.mys3.id

  topic {
    topic_arn = aws_sns_topic.mysns.arn
    events    = ["s3:ObjectRemoved:*"]
  }
}

# Enabling the KMS encryption
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
}

resource "aws_kms_key" "dest_key" {
  description             = "This key is used to encrypt bucket objects -destination key"
  deletion_window_in_days = 10
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mykms" {
  bucket = aws_s3_bucket.mys3.id

  rule {
    apply_server_side_encryption_by_default {
      kms_master_key_id = aws_kms_key.mykey.arn
      sse_algorithm     = "aws:kms"
    }
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "dest_enc" {
  bucket = aws_s3_bucket.destination.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm     = "aws:kms"
      kms_master_key_id = aws_kms_key.dest_key.arn
    }
  }
}

# iam role for replication
data "aws_iam_policy_document" "replication_trust" {
  statement {
    effect = "Allow"

    principals {
      type        = "Service"
      identifiers = ["s3.amazonaws.com"]
    }

    actions = ["sts:AssumeRole"]
  }
}

resource "aws_iam_role" "replication_role" {
  name               = "s3-replication-role"
  assume_role_policy = data.aws_iam_policy_document.replication_trust.json
}

data "aws_iam_policy_document" "replication_policy" {
  statement {
    effect = "Allow"

    actions = [
      "s3:GetObject",
      "s3:GetObjectVersion",
      "s3:GetObjectVersionAcl",
      "s3:GetObjectVersionForReplication",
      "s3:GetObjectVersionTagging",
      "s3:ListBucket"
    ]

    resources = [
      aws_s3_bucket.mys3.arn,
      "${aws_s3_bucket.mys3.arn}/*"
    ]
  }

  statement {
    effect = "Allow"

    actions = [
      "s3:ReplicateObject",
      "s3:ReplicateDelete",
      "s3:ReplicateTags",
      "s3:ObjectOwnerOverrideToBucketOwner"
    ]

    resources = [
      aws_s3_bucket.destination.arn,
      "${aws_s3_bucket.destination.arn}/*"
    ]
  }

  # KMS permissions for replicating encrypted objects
  statement {
    effect = "Allow"

    actions = [
      "kms:Encrypt",
      "kms:Decrypt",
      "kms:ReEncrypt*",
      "kms:GenerateDataKey*"
    ]

    resources = [
      aws_kms_key.mykey.arn,
      aws_kms_key.dest_key.arn
    ]
  }
}

resource "aws_iam_policy" "replication_policy" {
  name   = "S3ReplicationPolicy"
  policy = data.aws_iam_policy_document.replication_policy.json
}

resource "aws_iam_role_policy_attachment" "replication_attach" {
  role       = aws_iam_role.replication_role.name
  policy_arn = aws_iam_policy.replication_policy.arn
}

# Enabling cross region replication

resource "aws_s3_bucket" "destination" {
  bucket = "terraform-destination"
}

resource "aws_s3_bucket_replication_configuration" "replication" {
  region = "eu-central-1"

  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.destver]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.mys3.id

  rule {
    id = "examplerule"

    filter {
      prefix = "example"
    }

    status = "Enabled"

    destination {
      bucket        = aws_s3_bucket.destination.arn
      storage_class = "STANDARD"
    }
  }
}