# Design decisions and trade-offs

## 1. Terraform rather than Control Tower

AWS Control Tower builds a similar landing zone from the console and manages it for you. It is a good choice for a team that wants AWS to own the upgrades. It also brings AWS Config rules into every account, which are billed per evaluation, and its internals are less visible. Writing it in Terraform keeps every guardrail, account and permission in code review, in Git history, and testable. **Revisit** when a client wants Account Factory, drift detection and the Control Tower control library without writing them.

## 2. Four stacks, not one

One big configuration would mean every change risks every resource, and one state file holds the keys to everything. Splitting by lifecycle (organisation, logging, security, identity) keeps each plan small and reviewable, and lets the logging and security stacks be owned by different people. Stacks share data only through stack 01's outputs.

## 3. OU design: by purpose and risk, not by team

OUs follow what the accounts are for (Security, Infrastructure, Workloads/Prod, Workloads/NonProd, Sandbox) because guardrails attach to OUs, and guardrails follow risk. Production and non-production are separate OUs so production can get stricter policies later without touching development. A Suspended OU with a deny-all policy gives a safe holding place for accounts being closed.

## 4. Deny-list SCPs with a role exemption

The guardrails deny specific dangerous actions rather than allowing a fixed list. That keeps AWS's default `FullAWSAccess` in place and avoids breaking new services. The landing zone's own role is exempt from the protective statements, so the platform team can still run it. Everyone else, including each account's administrators, cannot.

## 5. Region restriction with global-service exemptions

Limiting regions shrinks the attack surface, keeps data in the UK and EU, and stops resources being forgotten in far-off regions. Global services (IAM, Organizations, Route 53, CloudFront, support, billing and others) have to be exempt or they stop working. The exemption list follows AWS's published example.

## 6. Tamper-evident logging

- One organisation trail in the management account captures every account and region, so no account can opt out.
- Logs live in a separate account that almost nobody has access to.
- Object Lock (governance mode, 365 days) blocks deletion, and a bucket policy denies delete actions to everyone except the landing zone role. Governance mode lets the landing zone role act in an emergency. Compliance mode would stop even the account's root user and cannot be shortened, which is right for regulated retention but unforgiving for a first deployment.
- Log file validation produces signed digests, so any edit is detectable.
- SCPs stop anyone stopping or editing the trail.

## 7. Paid security services behind switches

IAM Access Analyzer (external access findings) is free and always on. GuardDuty and Security Hub are built and tested, administered from the security-tooling account and auto-enabled for new accounts, but default to off because they bill after 30 days. A client would normally turn both on.

## 8. Identity Center rather than IAM users

People sign in once and assume a role in a chosen account for a limited time. Nothing long-lived exists to leak. Access is defined as data (`group -> permission set -> accounts`) and expanded by Terraform, so reviewing who can do what means reading one table. Admin sessions are capped at 4 hours, others at 8.

## 9. Accounts are never closed by Terraform

`close_on_deletion = false` on every account. Closing an AWS account starts a 90-day suspension and counts against an account quota. Removing an account from code should move it to Suspended first, so a typo cannot close production.

## 10. Testing without an organisation

Creating an organisation would take the development account off the AWS Free plan, and applying SCPs to a real organisation to test them is risky anyway. So the code is proven three ways: Terraform's native tests against a mocked provider (logic and wiring), IAM Access Analyzer (policy grammar, using AWS's own checker), and Checkov (security misconfiguration). The tests found a real bug during development: the `["*"]` ("every account") check compared a list with a tuple, which never matched, and would have failed at plan time.
