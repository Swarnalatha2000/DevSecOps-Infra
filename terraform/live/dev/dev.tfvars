buckets = {
    source = {
        name           = "terraform-cicd-source"
        enable_logging = true
    }
    destination = {
        name           = "terraform-cicd-destination"
        enable_logging = true
    }
    logs = {
        name           = "terraform-logs-source"
        enable_logging = false
    }
    logd = {
        name           = "terraform-logs-destination"
        enable_logging = false
    }
}