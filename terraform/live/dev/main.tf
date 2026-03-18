provider "aws" {
    region = "ap-south-1"
}

module "s3" {
    for_each = var.buckets

    source = "../../modules/s3"
    
    bucket_name = each.value.name
}