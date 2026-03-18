provider "aws" {
    region = "ap-south-1"
}

resource "aws_s3_bucket" "source" {
    bucket = "terraform-cicd"
}

resource "aws_s3_bucket" "destination" {
  bucket = "terraform-destination"
}

resource "aws_s3_bucket" "sourcelog" {
    bucket = "terraform-cicd-sourcelog"
}

resource "aws_s3_bucket" "destinationlog" {
  bucket = "terraform-cicd-destinationlog"
}

#Enabling the logging
resource "aws_s3_bucket_logging" "slog" {
    bucket = aws_s3_bucket.sourcelog.id
    
    target_bucket = aws_s3_bucket.source.id
    target_prefix = "log/"
}

resource "aws_s3_bucket_logging" "dlog" {
    bucket = aws_s3_bucket.destinationlog.id
    
    target_bucket = aws_s3_bucket.destination.id
    target_prefix = "log/"
}

resource "aws_s3_bucket_public_access_block" "buckpolicysource" {
    bucket = aws_s3_bucket.source.id
    
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_public_access_block" "buckpolicydestination" {
    bucket = aws_s3_bucket.destination.id
    
    block_public_acls       = true
    block_public_policy     = true
    ignore_public_acls      = true
    restrict_public_buckets = true
}

resource "aws_s3_bucket_versioning" "myver" {
  bucket = aws_s3_bucket.source.id
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

resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config-source" {
  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.myver]

  bucket = aws_s3_bucket.source.id

  rule {
    id = "default-lifecycle-rule"
    abort_incomplete_multipart_upload {
        days_after_initiation = 7
    }

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

resource "aws_s3_bucket_lifecycle_configuration" "versioning-bucket-config-destination" {
  # Must have bucket versioning enabled first for destination
  depends_on = [aws_s3_bucket_versioning.destver]

  bucket = aws_s3_bucket.destination.id

  rule {
    id = "default-lifecycle-rule-destination"
    abort_incomplete_multipart_upload {
        days_after_initiation = 7
    }

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
resource "aws_sns_topic" "mysnssource" {
  name = "my-topic"
  kms_master_key_id = "alias/aws/sns"
}

data "aws_iam_policy_document" "sns_s3_publish_source" {
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
      aws_sns_topic.mysnssource.arn
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.source.arn]   # your S3 bucket
    }
  }
}

resource "aws_sns_topic_policy" "sns_policy" {
  arn    = aws_sns_topic.mysnssource.arn
  policy = data.aws_iam_policy_document.sns_s3_publish_source.json
}

resource "aws_s3_bucket_notification" "sns_trigger_source" {
  bucket = aws_s3_bucket.source.id

  topic {
    topic_arn     = aws_sns_topic.mysnssource.arn
    events        = ["s3:ObjectRemoved:*"]
    filter_prefix = "logs/"
  }
}

resource "aws_sns_topic" "mysnsdestination" {
  name = "my-topic"
  kms_master_key_id = "alias/aws/sns"
}

data "aws_iam_policy_document" "sns_s3_publish_destination" {
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
      aws_sns_topic.mysnsdestination.arn
    ]

    condition {
      test     = "ArnLike"
      variable = "aws:SourceArn"
      values   = [aws_s3_bucket.destination.arn]   # your S3 bucket
    }
  }
}

resource "aws_sns_topic_policy" "sns_policy_destination" {
  arn    = aws_sns_topic.mysnsdestination.arn
  policy = data.aws_iam_policy_document.sns_s3_publish_destination.json
}

resource "aws_s3_bucket_notification" "sns_trigger" {
  bucket = aws_s3_bucket.destination.id

  topic {
    topic_arn     = aws_sns_topic.mysnsdestination.arn
    events        = ["s3:ObjectRemoved:*"]
    filter_prefix = "logs/"
  }
}

# Enabling the KMS encryption
resource "aws_kms_key" "mykey" {
  description             = "This key is used to encrypt bucket objects"
  deletion_window_in_days = 10
  enable_key_rotation    = true
  policy      = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::123456789012:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

resource "aws_kms_key" "dest_key" {
  description             = "This key is used to encrypt bucket objects -destination key"
  deletion_window_in_days = 10
  enable_key_rotation    = true
  policy      = <<POLICY
  {
    "Version": "2012-10-17",
    "Id": "default",
    "Statement": [
      {
        "Sid": "DefaultAllow",
        "Effect": "Allow",
        "Principal": {
          "AWS": "arn:aws:iam::123456789012:root"
        },
        "Action": "kms:*",
        "Resource": "*"
      }
    ]
  }
POLICY
}

resource "aws_s3_bucket_server_side_encryption_configuration" "mykms" {
  bucket = aws_s3_bucket.source.id

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
      kms_master_key_id = aws_kms_key.dest_key.arn
      sse_algorithm     = "aws:kms"
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
      aws_s3_bucket.source.arn,
      "${aws_s3_bucket.source.arn}/*"
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
resource "aws_s3_bucket_replication_configuration" "replication" {
  region = "eu-central-1"

  # Must have bucket versioning enabled first
  depends_on = [aws_s3_bucket_versioning.destver]

  role   = aws_iam_role.replication_role.arn
  bucket = aws_s3_bucket.source.id

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