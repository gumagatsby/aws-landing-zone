output "organization_id" {
  value = aws_organizations_organization.this.id
}

output "management_account_id" {
  value = aws_organizations_organization.this.master_account_id
}

output "ou_ids" {
  value = local.ou_ids
}

output "account_ids" {
  description = "Member account IDs by name, read by stacks 02 to 04"
  value       = { for k, v in aws_organizations_account.this : k => v.id }
}
