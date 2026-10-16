# Runs against a mocked AWS provider: no credentials, no AWS calls, no cost.
#   terraform init -backend=false && terraform test

mock_provider "aws" {
  mock_resource "aws_organizations_organization" {
    defaults = {
      id                = "o-test123456"
      master_account_id = "111111111111"
      roots             = [{ id = "r-root", arn = "arn:aws:organizations::111111111111:root/o-test123456/r-root", name = "Root", policy_types = [] }]
    }
  }
}

override_resource {
  target = aws_organizations_organizational_unit.top["Security"]
  values = { id = "ou-root-security1" }
}

override_resource {
  target = aws_organizations_organizational_unit.top["Infrastructure"]
  values = { id = "ou-root-infrastr1" }
}

override_resource {
  target = aws_organizations_organizational_unit.top["Workloads"]
  values = { id = "ou-root-workload1" }
}

override_resource {
  target = aws_organizations_organizational_unit.top["Sandbox"]
  values = { id = "ou-root-sandbox01" }
}

override_resource {
  target = aws_organizations_organizational_unit.top["Suspended"]
  values = { id = "ou-root-suspend01" }
}

override_resource {
  target = aws_organizations_organizational_unit.workloads["Prod"]
  values = { id = "ou-work-prod0001" }
}

override_resource {
  target = aws_organizations_organizational_unit.workloads["NonProd"]
  values = { id = "ou-work-nonprod01" }
}

override_resource {
  target = aws_organizations_policy.scp
  values = { id = "p-testpolicy" }
}

override_resource {
  target = aws_organizations_policy.tags
  values = { id = "p-testtagpol" }
}

override_resource {
  target = aws_organizations_account.this
  values = { id = "222222222222" }
}

variables {
  account_email_pattern = "owner+%s@example.com"
  budget_alert_email    = "owner@example.com"
}

run "ou_tree_has_expected_shape" {
  command = apply

  assert {
    condition     = length(aws_organizations_organizational_unit.top) == 5
    error_message = "Expected 5 top-level OUs."
  }
  assert {
    condition     = alltrue([for ou in aws_organizations_organizational_unit.top : ou.parent_id == "r-root"])
    error_message = "Top-level OUs must sit under the organisation root."
  }
  assert {
    condition     = alltrue([for ou in aws_organizations_organizational_unit.workloads : ou.parent_id == aws_organizations_organizational_unit.top["Workloads"].id])
    error_message = "Prod and NonProd must sit under Workloads."
  }
}

run "accounts_land_in_the_right_ou" {
  command = apply

  assert {
    condition     = aws_organizations_account.this["log-archive"].parent_id == aws_organizations_organizational_unit.top["Security"].id
    error_message = "log-archive must be in the Security OU."
  }
  assert {
    condition     = aws_organizations_account.this["workloads-prod"].parent_id == aws_organizations_organizational_unit.workloads["Prod"].id
    error_message = "workloads-prod must be in Workloads/Prod."
  }
  assert {
    condition     = aws_organizations_account.this["sandbox"].parent_id == aws_organizations_organizational_unit.top["Sandbox"].id
    error_message = "sandbox must be in the Sandbox OU."
  }
  assert {
    condition     = aws_organizations_account.this["log-archive"].email == "owner+log-archive@example.com"
    error_message = "Account email must follow the pattern."
  }
}

run "accounts_are_never_auto_closed" {
  command = apply

  assert {
    condition     = alltrue([for a in aws_organizations_account.this : a.close_on_deletion == false])
    error_message = "close_on_deletion must be false: closing an account is a 90-day, quota-bound operation."
  }
}

run "guardrails_attached_where_intended" {
  command = apply

  assert {
    condition     = aws_organizations_policy_attachment.scp["baseline-guardrails:root"].target_id == "r-root"
    error_message = "Baseline guardrails must apply to the whole organisation."
  }
  assert {
    condition     = aws_organizations_policy_attachment.scp["region-restriction:root"].target_id == "r-root"
    error_message = "Region restriction must apply to the whole organisation."
  }
  assert {
    condition     = aws_organizations_policy_attachment.scp["sandbox-limits:Sandbox"].target_id == aws_organizations_organizational_unit.top["Sandbox"].id
    error_message = "Sandbox limits must apply to the Sandbox OU only."
  }
  assert {
    condition     = aws_organizations_policy_attachment.scp["deny-all-suspended:Suspended"].target_id == aws_organizations_organizational_unit.top["Suspended"].id
    error_message = "Deny-all must apply to the Suspended OU only."
  }
  assert {
    condition     = length(aws_organizations_policy_attachment.scp) == 4
    error_message = "Expected exactly 4 SCP attachments."
  }
}

run "every_account_has_a_budget" {
  command = apply

  assert {
    condition     = length(aws_budgets_budget.account) == length(var.accounts)
    error_message = "Each member account needs a budget alert."
  }
}

run "rejects_bad_email_pattern" {
  command = plan
  variables {
    account_email_pattern = "owner@example.com"
  }
  expect_failures = [var.account_email_pattern]
}

run "rejects_unknown_ou" {
  command = plan
  variables {
    accounts = {
      typo = { ou = "Prodd", purpose = "x", monthly_budget_usd = 1 }
    }
  }
  expect_failures = [var.accounts]
}
