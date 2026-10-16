# Runbook

## Add a new account

1. Add an entry to `accounts` in `stacks/01-organization/variables.tf` (or a tfvars file), choosing its OU, purpose and monthly budget.
2. Open a pull request. CI runs the tests and policy checks; review the plan.
3. Apply stack 01. The account inherits every guardrail from its OU straight away.
4. If people need access, add the account name to the relevant groups in `stacks/04-identity` and apply.

New accounts are covered automatically by the organisation trail, Access Analyzer, and (if enabled) GuardDuty and Security Hub.

## Retire an account

1. Change its `ou` to `Suspended` and apply stack 01. Everything in it is now denied.
2. Confirm nothing depends on it, then close it from the console (Account settings). AWS keeps it suspended for 90 days.
3. Remove it from the map and apply. `close_on_deletion = false` means Terraform will never close an account on its own.

## Someone needs access

Add them to the right group in IAM Identity Center. If no group fits, add one to `var.access` in stack 04 rather than granting access by hand, so it stays reviewable.

## An SCP is blocking legitimate work

1. Check CloudTrail for the `AccessDenied` event; the error message names the policy type.
2. If the work is legitimate, change the policy in `policies/scp/`, run `./scripts/validate-policies.sh`, and open a pull request.
3. Do not detach the guardrail as a quick fix: it would apply to every account at once.

## Investigate an incident

Logs for every account are in the log-archive bucket under `AWSLogs/<organisation id>/<account id>/CloudTrail/<region>/`. Validate that they have not been altered:

```bash
aws cloudtrail validate-logs --trail-arn <trail arn> --start-time <ISO time>
```

Query them with Athena by creating a CloudTrail table over the bucket.

## Turn on GuardDuty or Security Hub

Apply stack 03 with `-var enable_guardduty=true` and/or `-var enable_security_hub=true`. Both start with a 30-day free trial; check the estimated cost in each service's console before the trial ends.
