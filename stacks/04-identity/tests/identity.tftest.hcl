# Mocked AWS: no credentials, no calls, no cost.

mock_provider "aws" {
  mock_resource "aws_ssoadmin_permission_set" {
    defaults = {
      arn = "arn:aws:sso:::permissionSet/ssoins-test/ps-test1234567890"
    }
  }
  mock_resource "aws_identitystore_group" {
    defaults = {
      group_id = "a1b2c3d4-0000-0000-0000-000000000000"
    }
  }
  mock_data "aws_ssoadmin_instances" {
    defaults = {
      arns               = ["arn:aws:sso:::instance/ssoins-test"]
      identity_store_ids = ["d-test12345"]
    }
  }
}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      management_account_id = "111111111111"
      account_ids = {
        log-archive       = "222222222201"
        security-tooling  = "222222222202"
        shared-services   = "222222222203"
        workloads-prod    = "222222222204"
        workloads-nonprod = "222222222205"
        sandbox           = "222222222206"
      }
    }
  }
}

variables {
  state_bucket = "tfstate-test"
}

run "admins_and_auditors_reach_every_account" {
  command = apply

  assert {
    condition     = length([for k, a in local.assignments : k if a.group == "platform-admins"]) == 7
    error_message = "Platform admins need access to all 6 member accounts plus management."
  }
  assert {
    condition     = length([for k, a in local.assignments : k if a.group == "security-auditors"]) == 7
    error_message = "Security auditors need read access everywhere."
  }
}

run "developers_cannot_change_production" {
  command = apply

  assert {
    condition     = !contains(keys(local.assignments), "developers:workloads-prod:Developer")
    error_message = "Developers must not have write access to production."
  }
  assert {
    condition     = contains(keys(local.assignments), "developers-prod-readonly:workloads-prod:ReadOnly")
    error_message = "Developers should be able to read production."
  }
}

run "finance_only_in_management" {
  command = apply

  assert {
    condition     = keys({ for k, a in local.assignments : k => a if a.group == "finance" }) == ["finance:management:Billing"]
    error_message = "Finance should only have Billing in the management account."
  }
}

run "admin_sessions_are_short" {
  command = apply

  assert {
    condition     = aws_ssoadmin_permission_set.this["PlatformAdmin"].session_duration == "PT4H"
    error_message = "Admin sessions should be capped at 4 hours."
  }
}

run "rejects_unknown_permission_set" {
  command = plan
  variables {
    access = {
      oops = { description = "x", permission_set = "GodMode", accounts = ["*"] }
    }
  }
  expect_failures = [var.access]
}
