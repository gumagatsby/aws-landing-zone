# Mocked AWS: no credentials, no calls, no cost.

mock_provider "aws" {}
mock_provider "aws" {
  alias = "security"
}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      account_ids = { security-tooling = "444444444444" }
    }
  }
}

variables {
  state_bucket = "tfstate-test"
}

run "free_baseline_only_by_default" {
  command = apply

  assert {
    condition     = aws_accessanalyzer_analyzer.org.type == "ORGANIZATION"
    error_message = "Access Analyzer must watch the whole organisation."
  }
  assert {
    condition     = aws_organizations_delegated_administrator.access_analyzer.account_id == "444444444444"
    error_message = "Access Analyzer must be administered from the security-tooling account."
  }
  assert {
    condition     = length(aws_guardduty_detector.security) == 0 && length(aws_securityhub_organization_admin_account.this) == 0
    error_message = "Paid services must be off unless explicitly enabled."
  }
}

run "guardduty_covers_every_account_when_enabled" {
  command = apply
  variables {
    enable_guardduty = true
  }

  assert {
    condition     = aws_guardduty_organization_admin_account.this[0].admin_account_id == "444444444444"
    error_message = "GuardDuty must be delegated to the security-tooling account."
  }
  assert {
    condition     = aws_guardduty_organization_configuration.this[0].auto_enable_organization_members == "ALL"
    error_message = "GuardDuty must auto-enable for all current and new accounts."
  }
}

run "security_hub_enables_standards_when_enabled" {
  command = apply
  variables {
    enable_security_hub = true
  }

  assert {
    condition     = aws_securityhub_organization_configuration.this[0].auto_enable
    error_message = "Security Hub must auto-enable for new accounts."
  }
}
