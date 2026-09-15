# _bootstrap

Provisions the shared Terraform state backend in AWS: the S3 bucket (`woofle-pemc-tfstate`), its versioning/SSE/public-access-block/lifecycle config, the KMS CMK used to encrypt it, and a bucket policy that enforces KMS encryption, HTTPS-only access, and blocks deletion of `terraform.tfstate` objects/versions. This runs in the **management** AWS account (`ap-south-1`), since it's the account that owns the org-wide state bucket every other stack backends into.

It also provisions the GitHub Actions OIDC provider and the two CI roles that every other stack's pipeline assumes to read/write its state: `pemc-tfstate-plan` and `pemc-tfstate-apply`.

## CI roles

Both roles are assumed via `sts:AssumeRoleWithWebIdentity` against the GitHub Actions OIDC provider (`aws_iam_openid_connect_provider.github_actions`) — no long-lived AWS credentials are stored in GitHub.

- **`pemc-tfstate-plan`** — assumable from any pull request in this repo (`token.actions.githubusercontent.com:sub = repo:.../pemc-infra@...:pull_request`). Read-only: `s3:ListBucket`/`s3:GetObject` on `live/*/terraform.tfstate`, lock-file management, and `kms:Decrypt`/`kms:GenerateDataKey` on the state CMK.
- **`pemc-tfstate-apply`** — assumable only from the `sandbox-apply` GitHub Actions environment. Everything `pemc-tfstate-plan` has, plus `s3:PutObject` on `live/*/terraform.tfstate`. `max_session_duration` is 3 hours (default 1 hour is tight for a long apply).

Both roles carry an explicit `DenyBootstrapStateAccess` statement blocking `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on `live/_bootstrap/*` and `live/sandbox/_bootstrap/*` — CI never plans or applies either bootstrap stack, so it has no business touching their state files even though the `live/*/terraform.tfstate` glob would otherwise match them.

## Running it

Needs the `management` AWS profile — this stack provisions resources in the management account, not a workload account.

```sh
export AWS_PROFILE=<management-account-profile>

terraform init
terraform plan
terraform apply
```

## State

This stack's own state lives in the bucket it creates:

- Bucket: `woofle-pemc-tfstate`
- Key: `live/_bootstrap/terraform.tfstate`
- Region: `ap-south-1`

(Bootstrapped via local state on first apply, then migrated to this backend.)

## Never run `terraform destroy` here

This is the state backend for every other stack in the repo. Destroying it destroys the state bucket and its KMS key — i.e. every other stack's state, gone. Don't run `terraform destroy` on this stack under any circumstances.

## `prevent_destroy`

The S3 bucket and KMS key both have `lifecycle { prevent_destroy = true }`. If a `terraform destroy` (or a plan that would replace/delete them) is ever run anyway, Terraform will refuse and error out on these two resources.

**If you deliberately need to tear this down** (e.g. decommissioning the whole environment), you have to remove the `lifecycle { prevent_destroy = true }` blocks from `main.tf` first, then run `terraform destroy`.

> **Only do this if you are 100% certain.** Removing the guard and destroying this stack deletes the state bucket and KMS key backing every other stack's Terraform state. There is no undo — make sure every other stack has been destroyed or migrated off this backend first, and that you have backups of the state bucket contents if there's any chance you'll need them.
