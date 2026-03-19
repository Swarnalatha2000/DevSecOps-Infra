buckets = {
    source = {
        name           = "terraform-cicd-prod-source"
        enable_logging = true
    }
    destination = {
        name           = "terraform-cicd-prod-destination"
        enable_logging = true
    }
    logs = {
        name           = "terraform-logs-prod-source"
        enable_logging = false
    }
    logd = {
        name           = "terraform-logs-prod-destination"
        enable_logging = false
    }
}