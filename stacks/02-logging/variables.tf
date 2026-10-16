variable "home_region" {
  type    = string
  default = "eu-west-2"
}

variable "state_bucket" {
  description = "S3 bucket holding the landing zone's Terraform state"
  type        = string
}

variable "log_retention_days" {
  description = "Days logs are locked against deletion. 365 is a common audit baseline."
  type        = number
  default     = 365

  validation {
    condition     = var.log_retention_days >= 90
    error_message = "Keep audit logs for at least 90 days."
  }
}
