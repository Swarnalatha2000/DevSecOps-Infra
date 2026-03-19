buckets = {
    source = {
        name           = "terraform-cicd-source-9640"
        enable_logging = true
    }
    destination = {
        name           = "terraform-cicd-destination-9640"
        enable_logging = true
    }
    logs = {
        name           = "terraform-logs-source-9640"
        enable_logging = false
    }
    logd = {
        name           = "terraform-logs-destination-9640"
        enable_logging = false
    }
}