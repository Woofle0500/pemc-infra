# sandbox/_bootstrap

Provisions the CI identity and access setup for the **sandbox** AWS account: a GitHub Actions OIDC provider, the `pemc-plan`/`pemc-apply` roles CI assumes to plan/apply against this account, a hardened trust policy on `OrganizationAccountAccessRole` for break-glass access, the shared CMK used by sandbox S3 buckets, and the plan output bucket used to hand plan output from `pemc-plan` to `pemc-apply` as well as for a human reviewer to read the human-readable plan. This runs in the **sandbox** AWS account (`ap-south-1`) — it's the account being provisioned into, distinct from the management account that owns the shared state bucket.

## CI roles

Both roles are assumed via `sts:AssumeRoleWithWebIdentity` against this account's own GitHub Actions OIDC provider (`aws_iam_openid_connect_provider.github_actions` — a separate provider from the one in `live/_bootstrap`, since OIDC providers are registered per-account).

- **`pemc-plan`** — assumable from any pull request in this repo. Has `ReadOnlyAccess` attached.
- **`pemc-apply`** — assumable only from the `sandbox-apply` GitHub Actions environment. Has `PowerUserAccess` attached, and `max_session_duration = 10800` (3 hours — the default 1 hour is tight for a long apply).

## Permission boundaries

Both roles have a permission boundary (`pemc-plan-boundary` / `pemc-apply-boundary`) attached, on top of their managed policy. It exists so that if a future change to either role's policy accidentally widens it beyond what plan/apply should ever need, the boundary still caps what it can actually do.

- **`pemc-plan-boundary`** denies IAM management, STS actions other than `GetCallerIdentity`, `secretsmanager:GetSecretValue`, `ssm:GetParameter*`, KMS decrypt/data-key generation on the state CMK, and `s3:GetObject` — plan should never be able to read a secret, decrypt anything, or pull object contents.
- **`pemc-apply-boundary`** denies the same class of things, scoped to what apply needs to still be able to create infrastructure:
  - Targeted IAM privilege-escalation actions (creating users/credentials, attaching policies to users/groups) rather than blanket `iam:*`, since apply does legitimately need to create/manage *roles*.
  - Boundary manipulation — apply can't remove/replace another role's boundary, or modify its own boundary policy.
  - `iam:CreateRole`/`PutRolePolicy`/`AttachRolePolicy` are denied *unless* the target role is itself constrained by this same boundary (`iam:PermissionsBoundary` condition) — otherwise apply could create an unbounded role and use it to escape its own limits.
  - `organizations:*`, `sso:*`, KMS decrypt/data-key generation on the state CMK, `kms:ScheduleKeyDeletion`/`DisableKey`, `sts:AssumeRole*` (apply has no legitimate reason to pivot into another role), deleting from the shared state bucket, `ec2:CreateNatGateway`, data-plane reads (DynamoDB items, SQS messages, log events), and credential-adjacent reads (EC2 instance password data, Lambda env config, ECR auth tokens).
  - `s3:GetObject` is denied everywhere *except* the plan output bucket (`DenyS3ObjectReadsExceptPlanOutput`, via `not_resources`) — apply has one legitimate reason to read object contents: pulling back the plan output `pemc-plan` wrote.

## Shared sandbox S3 CMK

`aws_kms_key.storage` / `aws_kms_alias.storage` is the CMK used by every general-purpose S3 bucket in the sandbox account (the plan output bucket below, and [ap-south-1/storage](../ap-south-1/storage), which looks it up by alias rather than provisioning its own). It lives here rather than in a consuming stack so it isn't tied to any one bucket's lifecycle.

## Plan output bucket

`aws_s3_bucket.plan_output` stores the plan output — the `tfplan` binary, `tfplan.json`, the human-readable `tfplan.txt`, and a `summary.json` — from `pemc-plan` (writes, on pull requests). Versioning is enabled for lifecycle behavior and overwrite visibility, not recovery — these are transient CI artifacts, expired after ~7 days current / ~1 day noncurrent (`aws_s3_bucket_lifecycle_configuration.plan_output`), and there's nothing worth restoring once they age out. No Object Lock.

Its bucket policy (`plan_output_bucket_policy`) is deny-only, same style as the state bucket policy in [live/_bootstrap](../../_bootstrap): denies `s3:PutObject` unless SSE-KMS with the correct key is specified, and denies any access over plain HTTP. Unlike the state bucket, it has no delete-protection statements — the plan output stored here isn't relied on for recovery.

IAM access:
- **`pemc-plan`** — `s3:PutObject` on `<bucket>/*`, plus `kms:GenerateDataKey*` on the CMK (needed to satisfy the encryption requirement above; `ReadOnlyAccess` doesn't cover either).
- **`pemc-apply`** — `s3:GetObject`/`s3:ListBucket`, granted explicitly even though `PowerUserAccess` already covers it, so the grant doesn't depend on that attachment staying as broad as it is today.

## Break-glass: `OrganizationAccountAccessRole`

This stack also manages the trust policy of `OrganizationAccountAccessRole` — the role AWS Organizations creates automatically when this account joins the org. Its trust is restricted to sessions whose principal ARN matches the management account's PEMCAdmin SSO role (`var.management_sso_admin_role_arn_pattern`), not the account root generally. It has `lifecycle { prevent_destroy = true }`, since this role is often the only way back into the account if Identity Center is broken — see [docs/runbooks/break-glass.md](../../../docs/runbooks/break-glass.md).


## Running it

This stack has a split credential requirement: its **state** lives in the management account's bucket, but the **resources** it provisions (OIDC provider, IAM roles) live in the sandbox account. So you need the management profile for the backend, and sandbox credentials active for the provider.

```sh
export AWS_PROFILE=<sandbox-account-profile>   # used by the aws provider to create resources

terraform init -backend-config=sandbox-backend-config.hcl.example   # backend-config's `profile` points at the management account
terraform plan
terraform apply
```
change `sandbox-backend-config.hcl.example` file:
```hcl
profile = <management-account-profile>
```

## State

- Bucket: `woofle-pemc-tfstate`
- Key: `live/sandbox/_bootstrap/terraform.tfstate`
- Region: `ap-south-1`

Same bucket/CMK as every other stack, in the management account.

