variable "bucket_name" {
    type = string
}

variable "enable_logging" {
    type    = bool
    default = false
}

variable "log_bucket" {
    type    = string
    default = null
}

variable "lifecycle_days" {
    type    = number
    default = 30
}