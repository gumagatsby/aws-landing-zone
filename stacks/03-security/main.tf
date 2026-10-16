# Stack 03: security services run centrally from the security-tooling account.
# The management account delegates administration; the security account then
# switches each service on for every current and future member account.
#
# Cost switches: IAM Access Analyzer (external access) is free and always on.
# GuardDuty and Security Hub bill after a 30-day trial, so they are off by default.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "landing-zone/03-security.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

data "terraform_remote_state" "org" {
  backend = "s3"
  config = {
    bucket = var.state_bucket
    key    = "landing-zone/01-organization.tfstate"
    region = var.home_region
  }
}

locals {
  security_id = data.terraform_remote_state.org.outputs.account_ids["security-tooling"]
}

provider "aws" {
  region = var.home_region
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-03-security" } }
}

provider "aws" {
  alias  = "security"
  region = var.home_region
  assume_role {
    role_arn     = "arn:aws:iam::${local.security_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-landing-zone"
  }
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-03-security" } }
}

# ---------------------------------------------------------------- IAM Access Analyzer (free)
# Flags any resource (bucket, role, key, queue...) shared outside the organisation.
resource "aws_organizations_delegated_administrator" "access_analyzer" {
  account_id        = local.security_id
  service_principal = "access-analyzer.amazonaws.com"
}

resource "aws_accessanalyzer_analyzer" "org" {
  provider      = aws.security
  analyzer_name = "organization-external-access"
  type          = "ORGANIZATION"
  depends_on    = [aws_organizations_delegated_administrator.access_analyzer]
}

# ---------------------------------------------------------------- GuardDuty (opt-in: billed after trial)
resource "aws_guardduty_organization_admin_account" "this" {
  count            = var.enable_guardduty ? 1 : 0
  admin_account_id = local.security_id
}

resource "aws_guardduty_detector" "security" {
  count    = var.enable_guardduty ? 1 : 0
  provider = aws.security
  enable   = true
}

resource "aws_guardduty_organization_configuration" "this" {
  count                            = var.enable_guardduty ? 1 : 0
  provider                         = aws.security
  detector_id                      = aws_guardduty_detector.security[0].id
  auto_enable_organization_members = "ALL" # new accounts are covered automatically
  depends_on                       = [aws_guardduty_organization_admin_account.this]
}

# ---------------------------------------------------------------- Security Hub (opt-in: billed after trial)
resource "aws_securityhub_organization_admin_account" "this" {
  count            = var.enable_security_hub ? 1 : 0
  admin_account_id = local.security_id
}

resource "aws_securityhub_organization_configuration" "this" {
  count                 = var.enable_security_hub ? 1 : 0
  provider              = aws.security
  auto_enable           = true
  auto_enable_standards = "DEFAULT" # AWS Foundational Security Best Practices
  depends_on            = [aws_securityhub_organization_admin_account.this]
}
