variable "home_region" {
  type    = string
  default = "eu-west-2"
}

variable "account_email_pattern" {
  description = "printf pattern for member account root emails; %s becomes the account name. Plus-addressing works: you+%s@example.com"
  type        = string

  validation {
    condition     = strcontains(var.account_email_pattern, "%s") && strcontains(var.account_email_pattern, "@")
    error_message = "Must be an email pattern containing %s, e.g. you+%s@example.com."
  }
}

variable "budget_alert_email" {
  type = string
}

variable "accounts" {
  description = "Member accounts: which OU each sits in, what it is for, and its monthly budget"
  type = map(object({
    ou                 = string
    purpose            = string
    monthly_budget_usd = number
  }))
  default = {
    log-archive       = { ou = "Security", purpose = "Organisation CloudTrail and access logs, write-once", monthly_budget_usd = 5 }
    security-tooling  = { ou = "Security", purpose = "Delegated admin for GuardDuty, Security Hub, Access Analyzer", monthly_budget_usd = 10 }
    shared-services   = { ou = "Infrastructure", purpose = "Networking and CI/CD shared by workloads", monthly_budget_usd = 10 }
    workloads-prod    = { ou = "Workloads/Prod", purpose = "Production applications", monthly_budget_usd = 25 }
    workloads-nonprod = { ou = "Workloads/NonProd", purpose = "Development and test", monthly_budget_usd = 10 }
    sandbox           = { ou = "Sandbox", purpose = "Experiments, cost-capped by SCP", monthly_budget_usd = 5 }
  }

  validation {
    condition     = alltrue([for a in values(var.accounts) : contains(["Security", "Infrastructure", "Workloads/Prod", "Workloads/NonProd", "Sandbox", "Suspended"], a.ou)])
    error_message = "Each account's ou must be one of: Security, Infrastructure, Workloads/Prod, Workloads/NonProd, Sandbox, Suspended."
  }
}
