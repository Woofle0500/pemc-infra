# _bootstrap

Provisions the shared Terraform state backend in AWS: the S3 bucket (`woofle-pemc-tfstate`), its versioning/SSE/public-access-block/lifecycle config, the KMS CMK used to encrypt it, and a bucket policy that enforces KMS encryption, HTTPS-only access, and blocks deletion of `terraform.tfstate` objects/versions. This runs in the **management** AWS account (`ap-south-1`), since it's the account that owns the org-wide state bucket every other stack backends into. It also owns the central Terraform run bucket (below), for the same reason: it's the one account every stack's CI pipeline already has a role in.

It also provisions the GitHub Actions OIDC provider and the two CI roles that every other stack's pipeline assumes: `pemc-management-plan` and `pemc-management-apply`.

## CI roles

Both roles are assumed via `sts:AssumeRoleWithWebIdentity` against the GitHub Actions OIDC provider (`aws_iam_openid_connect_provider.github_actions`) — no long-lived AWS credentials are stored in GitHub.

- **`pemc-management-plan`** — assumable from any pull request in this repo (`token.actions.githubusercontent.com:sub = repo:.../pemc-infra@...:pull_request`). Read-only on state: `s3:ListBucket`/`s3:GetObject` on `live/*/terraform.tfstate`, lock-file management, and `kms:Decrypt`/`kms:GenerateDataKey` on the shared CMK. Also `s3:PutObject` on the run bucket (see below) — no extra KMS grant needed, `kms:GenerateDataKey` is already covered by the state permissions since it's the same key.
- **`pemc-management-apply`** — assumable only from the `sandbox-apply` GitHub Actions environment. Everything `pemc-management-plan` has (including the run-bucket write, inherited via `source_policy_documents`, but kept explicit here too — see `WriteRunObjectsExplicit`), plus `s3:PutObject` on `live/*/terraform.tfstate`, and `s3:GetObject`/`s3:ListBucket` on the run bucket (to read back `summary.json` before applying, and to write its own apply output after). `max_session_duration` is 3 hours (default 1 hour is tight for a long apply).

Both roles carry an explicit `DenyBootstrapStateAccess` statement blocking `s3:GetObject`/`s3:PutObject`/`s3:DeleteObject` on `live/_bootstrap/*` and `live/sandbox/_bootstrap/*` — CI never plans or applies either bootstrap stack, so it has no business touching their state files even though the `live/*/terraform.tfstate` glob would otherwise match them.

## Shared CMK

`aws_kms_key.management_cmk` / `aws_kms_alias.management_cmk` (`alias/woofle-pemc-s3-shared`) is the CMK used by both the state bucket and the run bucket below.

## Terraform run bucket

`aws_s3_bucket.tf_run` (`woofle-pemc-tf-run`) holds per-run Terraform artifacts from both CI roles: `pemc-management-plan` writes plan output on pull requests; `pemc-management-apply` reads back while applying and writes its own outputs afterward. It's central across every account this repo provisions into, not per-account, because both CI roles that need it already live here rather than in each workload account — no cross-account bucket/key policy is needed. Versioning is enabled for lifecycle behavior and overwrite visibility, not recovery — these are transient CI artifacts, expired after ~7 days current / ~1 day noncurrent (`aws_s3_bucket_lifecycle_configuration.tf_run`), and there's nothing worth restoring once they age out. No Object Lock.

Its bucket policy (`tf_run_bucket_policy`) is deny-only, same style as the state bucket policy above: denies `s3:PutObject` unless SSE-KMS with the correct key is specified, and denies any access over plain HTTP. Unlike the state bucket, it has no delete-protection statements — the run artifacts stored here aren't relied on for recovery.

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
