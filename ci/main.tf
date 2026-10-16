# A read-only role for this repository's CI, in the account the code is developed in.
# It can only call IAM Access Analyzer's free ValidatePolicy API, so CI can check the
# guardrail policies against AWS's own linter. It cannot read or change anything.
#
# Reuses the GitHub OIDC provider that already exists in the account.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "landing-zone/ci.tfstate"
    encrypt      = true
    use_lockfile = true
  }
}

provider "aws" {
  region = "eu-west-2"
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-ci" } }
}

variable "github_subject_prefix" {
  description = "From: gh api repos/<owner>/<repo>/actions/oidc/customization/sub --jq .sub_claim_prefix"
  type        = string
}

data "aws_iam_openid_connect_provider" "github" {
  url = "https://token.actions.githubusercontent.com"
}

resource "aws_iam_role" "ci" {
  name                 = "github-ci-aws-landing-zone"
  max_session_duration = 3600
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect    = "Allow"
      Principal = { Federated = data.aws_iam_openid_connect_provider.github.arn }
      Action    = "sts:AssumeRoleWithWebIdentity"
      Condition = {
        StringEquals = { "token.actions.githubusercontent.com:aud" = "sts.amazonaws.com" }
        StringLike = {
          "token.actions.githubusercontent.com:sub" = [
            "${var.github_subject_prefix}:ref:refs/heads/main",
            "${var.github_subject_prefix}:pull_request",
          ]
        }
      }
    }]
  })
}

resource "aws_iam_role_policy" "validate_only" {
  name = "validate-policies-only"
  role = aws_iam_role.ci.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = "access-analyzer:ValidatePolicy"
      Resource = "*"
    }]
  })
}

output "ci_role_arn" {
  value = aws_iam_role.ci.arn
}
