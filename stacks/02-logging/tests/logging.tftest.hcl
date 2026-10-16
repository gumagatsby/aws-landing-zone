# Mocked AWS: no credentials, no calls, no cost.

mock_provider "aws" {}
mock_provider "aws" {
  alias = "log_archive"
}

override_resource {
  target = aws_s3_bucket.trail
  values = { arn = "arn:aws:s3:::org-cloudtrail-333333333333-eu-west-2", id = "org-cloudtrail-333333333333-eu-west-2" }
}

override_data {
  target = data.terraform_remote_state.org
  values = {
    outputs = {
      organization_id       = "o-test123456"
      management_account_id = "111111111111"
      account_ids           = { log-archive = "333333333333" }
    }
  }
}

variables {
  state_bucket = "tfstate-test"
}

run "trail_covers_whole_organisation" {
  command = apply

  assert {
    condition     = aws_cloudtrail.org.is_organization_trail && aws_cloudtrail.org.is_multi_region_trail
    error_message = "The trail must cover every account and every region."
  }
  assert {
    condition     = aws_cloudtrail.org.enable_log_file_validation
    error_message = "Log file validation must be on so tampering can be detected."
  }
}

run "logs_go_to_the_log_archive_account" {
  command = apply

  assert {
    condition     = aws_s3_bucket.trail.bucket == "org-cloudtrail-333333333333-eu-west-2"
    error_message = "Bucket must be named for, and live in, the log-archive account."
  }
  assert {
    condition     = aws_s3_bucket.trail.object_lock_enabled
    error_message = "Object Lock must be enabled at creation."
  }
  assert {
    condition     = aws_s3_bucket_object_lock_configuration.trail.rule[0].default_retention[0].days == 365
    error_message = "Default retention should be 365 days."
  }
}

run "bucket_policy_is_scoped_to_this_trail" {
  command = apply

  assert {
    condition     = strcontains(local.trail_bucket_policy, "arn:aws:cloudtrail:eu-west-2:111111111111:trail/organization-trail")
    error_message = "CloudTrail write access must be limited to this trail's ARN."
  }
  assert {
    condition     = strcontains(local.trail_bucket_policy, "DenyLogDeletion")
    error_message = "Bucket policy must deny log deletion."
  }
}

run "rejects_short_retention" {
  command = plan
  variables {
    log_retention_days = 30
  }
  expect_failures = [var.log_retention_days]
}
