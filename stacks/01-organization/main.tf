# Stack 01: the organisation itself.
# Applied from the management account. Creates the OU tree, the member accounts,
# the guardrail policies (SCPs) and a tag policy, and attaches each to the right OU.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "landing-zone/01-organization.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.home_region
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-01-organization" } }
}

# ---------------------------------------------------------------- organisation
resource "aws_organizations_organization" "this" {
  feature_set = "ALL"
  enabled_policy_types = [
    "SERVICE_CONTROL_POLICY",
    "TAG_POLICY",
  ]
  # Services that act across every account. Each one is free to enable;
  # GuardDuty and Security Hub only cost money once switched on in stack 03.
  aws_service_access_principals = [
    "cloudtrail.amazonaws.com",
    "config.amazonaws.com",
    "guardduty.amazonaws.com",
    "securityhub.amazonaws.com",
    "access-analyzer.amazonaws.com",
    "sso.amazonaws.com",
    "account.amazonaws.com",
  ]
}

locals {
  root_id = aws_organizations_organization.this.roots[0].id
}

# ---------------------------------------------------------------- OU tree
#  Root
#  ├── Security        log archive, security tooling
#  ├── Infrastructure  shared services (networking, CI/CD)
#  ├── Workloads
#  │   ├── Prod
#  │   └── NonProd
#  ├── Sandbox         experiments, cost-capped
#  └── Suspended       accounts being closed: everything denied
resource "aws_organizations_organizational_unit" "top" {
  for_each  = toset(["Security", "Infrastructure", "Workloads", "Sandbox", "Suspended"])
  name      = each.key
  parent_id = local.root_id
}

resource "aws_organizations_organizational_unit" "workloads" {
  for_each  = toset(["Prod", "NonProd"])
  name      = each.key
  parent_id = aws_organizations_organizational_unit.top["Workloads"].id
}

locals {
  ou_ids = merge(
    { for k, v in aws_organizations_organizational_unit.top : k => v.id },
    { for k, v in aws_organizations_organizational_unit.workloads : "Workloads/${k}" => v.id },
  )
}

# ---------------------------------------------------------------- accounts
resource "aws_organizations_account" "this" {
  for_each = var.accounts

  name      = each.key
  email     = format(var.account_email_pattern, each.key)
  parent_id = local.ou_ids[each.value.ou]
  role_name = "OrganizationAccountAccessRole"

  # Closing an AWS account is slow (90-day suspension) and counts against a quota.
  # Removing an account from this map should move it to Suspended first, not close it.
  close_on_deletion = false

  tags = { Purpose = each.value.purpose }

  lifecycle {
    # AWS does not let the role name change after creation; ignore drift on it.
    ignore_changes = [role_name]
  }
}

# ---------------------------------------------------------------- guardrails (SCPs)
locals {
  scp_dir = "${path.module}/../../policies/scp"
  scps = {
    baseline-guardrails = {
      description = "Protect the audit trail, security services and landing zone role; deny root; stay in the organisation"
      targets     = ["root"]
    }
    region-restriction = {
      description = "Only eu-west-2 and eu-west-1, except global services"
      targets     = ["root"]
    }
    sandbox-limits = {
      description = "No reserved capacity, NAT gateways, clusters or large instances in Sandbox"
      targets     = ["Sandbox"]
    }
    deny-all-suspended = {
      description = "Accounts waiting to be closed can do nothing"
      targets     = ["Suspended"]
    }
  }
  scp_attachments = merge([
    for name, p in local.scps : {
      for t in p.targets : "${name}:${t}" => { policy = name, target = t == "root" ? local.root_id : local.ou_ids[t] }
    }
  ]...)
}

resource "aws_organizations_policy" "scp" {
  for_each    = local.scps
  name        = each.key
  description = each.value.description
  type        = "SERVICE_CONTROL_POLICY"
  content     = file("${local.scp_dir}/${each.key}.json")
}

resource "aws_organizations_policy_attachment" "scp" {
  for_each  = local.scp_attachments
  policy_id = aws_organizations_policy.scp[each.value.policy].id
  target_id = each.value.target
}

# ---------------------------------------------------------------- tag policy
# Standard tags with fixed spellings, so cost reports group cleanly.
resource "aws_organizations_policy" "tags" {
  name        = "standard-tags"
  description = "Consistent spelling and values for Environment and Owner tags"
  type        = "TAG_POLICY"
  content = jsonencode({
    tags = {
      Environment = {
        tag_key   = { "@@assign" = "Environment" }
        tag_value = { "@@assign" = ["prod", "nonprod", "sandbox", "shared"] }
      }
      Owner = {
        tag_key = { "@@assign" = "Owner" }
      }
    }
  })
}

resource "aws_organizations_policy_attachment" "tags" {
  policy_id = aws_organizations_policy.tags.id
  target_id = local.root_id
}

# ---------------------------------------------------------------- budgets
# One alert per member account. Budget notifications are free.
resource "aws_budgets_budget" "account" {
  for_each     = aws_organizations_account.this
  name         = "account-${each.key}"
  budget_type  = "COST"
  limit_amount = tostring(var.accounts[each.key].monthly_budget_usd)
  limit_unit   = "USD"
  time_unit    = "MONTHLY"

  cost_filter {
    name   = "LinkedAccount"
    values = [each.value.id]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 80
    threshold_type             = "PERCENTAGE"
    notification_type          = "ACTUAL"
    subscriber_email_addresses = [var.budget_alert_email]
  }

  notification {
    comparison_operator        = "GREATER_THAN"
    threshold                  = 100
    threshold_type             = "PERCENTAGE"
    notification_type          = "FORECASTED"
    subscriber_email_addresses = [var.budget_alert_email]
  }
}
