terraform {
    backend "s3" {
        bucket       = "terraform-state-swarna"
        key          = "/dev/terraform.tfstate"
        region       = "ap-south-1"
        dynamo-table = "terraform-lock-table"
        encrypt      = true
    }
}