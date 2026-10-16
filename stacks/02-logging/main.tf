# Stack 02: one audit trail for the whole organisation.
# The trail is created in the management account and records every account and region.
# Logs land in a separate log-archive account, in a bucket nobody can quietly edit:
# versioned, Object Lock (governance), TLS only, and SCP-protected trail settings.

terraform {
  required_version = ">= 1.10.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
  backend "s3" {
    key          = "landing-zone/02-logging.tfstate"
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
  org_id         = data.terraform_remote_state.org.outputs.organization_id
  management_id  = data.terraform_remote_state.org.outputs.management_account_id
  log_archive_id = data.terraform_remote_state.org.outputs.account_ids["log-archive"]
  trail_name     = "organization-trail"
  trail_arn      = "arn:aws:cloudtrail:${var.home_region}:${local.management_id}:trail/${local.trail_name}"
  bucket_name    = "org-cloudtrail-${local.log_archive_id}-${var.home_region}"
}

provider "aws" {
  region = var.home_region
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-02-logging" } }
}

# Same Terraform run, acting inside the log-archive account through the role
# AWS Organizations created there.
provider "aws" {
  alias  = "log_archive"
  region = var.home_region
  assume_role {
    role_arn     = "arn:aws:iam::${local.log_archive_id}:role/OrganizationAccountAccessRole"
    session_name = "terraform-landing-zone"
  }
  default_tags { tags = { ManagedBy = "terraform", Stack = "landing-zone-02-logging" } }
}

# ---------------------------------------------------------------- log bucket (log-archive account)
resource "aws_s3_bucket" "trail" {
  provider            = aws.log_archive
  bucket              = local.bucket_name
  object_lock_enabled = true # can only be switched on at creation
}

resource "aws_s3_bucket_versioning" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  versioning_configuration { status = "Enabled" }
}

resource "aws_s3_bucket_object_lock_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  rule {
    default_retention {
      mode = "GOVERNANCE" # COMPLIANCE would stop even the account root deleting early
      days = var.log_retention_days
    }
  }
  depends_on = [aws_s3_bucket_versioning.trail]
}

resource "aws_s3_bucket_public_access_block" "trail" {
  provider                = aws.log_archive
  bucket                  = aws_s3_bucket.trail.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}

resource "aws_s3_bucket_lifecycle_configuration" "trail" {
  provider = aws.log_archive
  bucket   = aws_s3_bucket.trail.id
  rule {
    id     = "archive-then-expire"
    status = "Enabled"
    filter {}
    transition {
      days          = 90
      storage_class = "GLACIER_IR" # cheaper, still readable in milliseconds for investigations
    }
    expiration { days = var.log_retention_days + 30 }
    noncurrent_version_expiration { noncurrent_days = var.log_retention_days + 30 }
    abort_incomplete_multipart_upload { days_after_initiation = 1 }
  }
}

locals {
  trail_bucket_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid       = "CloudTrailAclCheck"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:GetBucketAcl"
        Resource  = aws_s3_bucket.trail.arn
        Condition = { StringEquals = { "aws:SourceArn" = local.trail_arn } }
      },
      # Organisation trails write under AWSLogs/<org id>/ and the management account's own prefix.
      {
        Sid       = "CloudTrailWrite"
        Effect    = "Allow"
        Principal = { Service = "cloudtrail.amazonaws.com" }
        Action    = "s3:PutObject"
        Resource = [
          "${aws_s3_bucket.trail.arn}/AWSLogs/${local.management_id}/*",
          "${aws_s3_bucket.trail.arn}/AWSLogs/${local.org_id}/*",
        ]
        Condition = {
          StringEquals = {
            "s3:x-amz-acl"  = "bucket-owner-full-control"
            "aws:SourceArn" = local.trail_arn
          }
        }
      },
      {
        Sid       = "DenyInsecureTransport"
        Effect    = "Deny"
        Principal = "*"
        Action    = "s3:*"
        Resource  = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
        Condition = { Bool = { "aws:SecureTransport" = "false" } }
      },
      # Logs are evidence: no one deletes them, and the bucket policy cannot be loosened
      # except by the landing zone role.
      {
        Sid       = "DenyLogDeletion"
        Effect    = "Deny"
        Principal = "*"
        Action    = ["s3:DeleteObject", "s3:DeleteObjectVersion", "s3:PutLifecycleConfiguration", "s3:DeleteBucketPolicy"]
        Resource  = [aws_s3_bucket.trail.arn, "${aws_s3_bucket.trail.arn}/*"]
        Condition = { ArnNotLike = { "aws:PrincipalArn" = "arn:aws:iam::${local.log_archive_id}:role/OrganizationAccountAccessRole" } }
      },
    ]
  })
}

resource "aws_s3_bucket_policy" "trail" {
  provider   = aws.log_archive
  bucket     = aws_s3_bucket.trail.id
  policy     = local.trail_bucket_policy
  depends_on = [aws_s3_bucket_public_access_block.trail]
}

# ---------------------------------------------------------------- organisation trail (management account)
resource "aws_cloudtrail" "org" {
  name                          = local.trail_name
  s3_bucket_name                = aws_s3_bucket.trail.id
  is_organization_trail         = true
  is_multi_region_trail         = true
  include_global_service_events = true
  enable_log_file_validation    = true # signed digest files prove logs were not altered

  # Management events only. Data events (every S3 read, every Lambda call) are billed per event.
  event_selector {
    read_write_type           = "All"
    include_management_events = true
  }

  depends_on = [aws_s3_bucket_policy.trail]
}
