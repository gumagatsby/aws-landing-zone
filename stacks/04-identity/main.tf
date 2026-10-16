# Stack 04: who can get into which account, and with what rights.
# People sign in once through IAM Identity Center and pick an account and role.
# No IAM users, no long-lived access keys. Identity Center itself is free.
#
# Prerequisite: enable IAM Identity Center once in the console (management account).
# AWS does not expose instance creation for organisation instances through the API.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "landing-zone/04-identity.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = var.home_region
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-04-identity" } }
}

data "terraform_remote_state" "org" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "landing-zone/01-organization.tfstate"
    region = var.home_region
  }
}

data "aws_ssoadmin_instances" "this" {}

locals {
  instance_arn      = one(data.aws_ssoadmin_instances.this.arns)
  identity_store_id = one(data.aws_ssoadmin_instances.this.identity_store_ids)
  accounts = merge(
    data.terraform_remote_state.org.outputs.account_ids,
    { management = data.terraform_remote_state.org.outputs.management_account_id },
  )
}

# ---------------------------------------------------------------- permission sets
# Shorter sessions for more powerful roles.
locals {
  permission_sets = {
    PlatformAdmin = { policy = "arn:aws:iam::aws:policy/AdministratorAccess", session = "PT4H", description = "Full control, short sessions" }
    Developer     = { policy = "arn:aws:iam::aws:policy/PowerUserAccess", session = "PT8H", description = "Build and run workloads; no IAM changes" }
    ReadOnly      = { policy = "arn:aws:iam::aws:policy/ReadOnlyAccess", session = "PT8H", description = "Look, do not touch" }
    SecurityAudit = { policy = "arn:aws:iam::aws:policy/SecurityAudit", session = "PT8H", description = "Read security configuration everywhere" }
    Billing       = { policy = "arn:aws:iam::aws:policy/job-function/Billing", session = "PT8H", description = "Costs, budgets and invoices" }
  }
}

resource "aws_ssoadmin_permission_set" "this" {
  for_each         = local.permission_sets
  name             = each.key
  description      = each.value.description
  instance_arn     = local.instance_arn
  session_duration = each.value.session
}

resource "aws_ssoadmin_managed_policy_attachment" "this" {
  for_each           = local.permission_sets
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.key].arn
  managed_policy_arn = each.value.policy
}

# ---------------------------------------------------------------- groups
resource "aws_identitystore_group" "this" {
  for_each          = var.access
  identity_store_id = local.identity_store_id
  display_name      = each.key
  description       = each.value.description
}

# ---------------------------------------------------------------- who gets what, where
# Flatten the access map into one assignment per group x account x permission set.
locals {
  assignments = merge([
    for group, g in var.access : {
      for pair in setproduct(contains(g.accounts, "*") ? keys(local.accounts) : g.accounts, [g.permission_set]) :
      "${group}:${pair[0]}:${pair[1]}" => { group = group, account = pair[0], permission_set = pair[1] }
    }
  ]...)
}

resource "aws_ssoadmin_account_assignment" "this" {
  for_each           = local.assignments
  instance_arn       = local.instance_arn
  permission_set_arn = aws_ssoadmin_permission_set.this[each.value.permission_set].arn
  principal_type     = "GROUP"
  principal_id       = aws_identitystore_group.this[each.value.group].group_id
  target_type        = "AWS_ACCOUNT"
  target_id          = local.accounts[each.value.account]
}
