variable "buckets" {
    type = map(object ({ 
        name           = string
        enable_logging = bool 
    }))
}