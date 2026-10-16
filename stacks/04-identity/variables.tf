variable "home_region" {
  type    = string
  default = "eu-west-2"
}

variable "state_bucket" {
  type = string
}

variable "access" {
  description = "One group per entry: the permission set it gets and the accounts it gets it in. [\"*\"] means every account."
  type = map(object({
    description    = string
    permission_set = string
    accounts       = list(string)
  }))
  default = {
    platform-admins = {
      description    = "Run the landing zone itself"
      permission_set = "PlatformAdmin"
      accounts       = ["*"]
    }
    developers = {
      description    = "Build in non-production and sandbox"
      permission_set = "Developer"
      accounts       = ["workloads-nonprod", "sandbox"]
    }
    developers-prod-readonly = {
      description    = "Developers can see production but not change it"
      permission_set = "ReadOnly"
      accounts       = ["workloads-prod"]
    }
    security-auditors = {
      description    = "Review security configuration across every account"
      permission_set = "SecurityAudit"
      accounts       = ["*"]
    }
    finance = {
      description    = "Costs and invoices, management account only"
      permission_set = "Billing"
      accounts       = ["management"]
    }
  }

  validation {
    condition     = alltrue([for g in values(var.access) : contains(["PlatformAdmin", "Developer", "ReadOnly", "SecurityAudit", "Billing"], g.permission_set)])
    error_message = "permission_set must be one of PlatformAdmin, Developer, ReadOnly, SecurityAudit, Billing."
  }
}
