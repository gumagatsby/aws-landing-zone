variable "home_region" {
  type    = string
  default = "eu-west-2"
}

variable "state_bucket" {
  type = string
}

variable "enable_guardduty" {
  description = "Threat detection across all accounts. Free for 30 days, then billed by volume."
  type        = bool
  default     = false
}

variable "enable_security_hub" {
  description = "Posture checks against AWS best practice. Free for 30 days, then billed per check."
  type        = bool
  default     = false
}
