provider "aws" {
    region = "ap-south-1"
}

# Create log_bucket
module "log_bucket" {
    source         = "../../modules/s3"

    bucket_name    = var.buckets["logs"].name
    enable_logging = false
}

module "s3" {
    for_each = var.buckets

    source = "../../modules/s3"
    
    bucket_name    = each.value.name
    enable_logging = each.value.enable_logging
    log_bucket     = var.buckets["logs"].name
}