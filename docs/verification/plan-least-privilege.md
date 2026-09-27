# Verification: the plan roles are least-privilege

## Claim

`pemc-plan` (sandbox) and `pemc-management-plan` (management) — the two roles every stack's plan job assumes — cannot write workload resources, cannot read secrets, and cannot write Terraform state directly. They can only do what a plan needs: read-only discovery, plus lock-file management on state.

## Why it holds

The guarantee cannot rest on what the Terraform defining these roles says, for the same reason [validate-no-credentials.md](validate-no-credentials.md) gives: the IAM policy is the intent, not the proof. `assert-least-privilege` in `plan.yaml` proves it by actually assuming each role in CI and calling AWS with it.

## Verification

Every probe here is inverted: it's expected to fail, and the job only passes if it fails for the *specific* reason expected. A probe that unexpectedly succeeds, or fails for an unrelated reason, fails the job.

Four denials:

1. **`pemc-plan` cannot write in the sandbox account** — a `--dry-run` `ec2:CreateKeyPair` call must come back `UnauthorizedOperation`. Dry-run makes EC2 evaluate IAM only, without performing the write, so this doesn't need any real resource to exist first.
2. **`pemc-plan` cannot read SSM parameters** — `ssm:GetParameter` on `/pemc/kill-switch` must come back `AccessDenied`.
3. **`pemc-plan` cannot read object contents in a sandbox bucket** — `s3:GetObject` on the canary bucket (see below) must come back `AccessDenied`, not a 404.
4. **`pemc-management-plan` cannot write state** — `s3:PutObject` on a `terraform.tfstate` key must come back `AccessDenied`. Uses a canary prefix (`live/_assert-least-privilege-canary`) that doesn't correspond to any real stack's state, so a bug here can't corrupt anything.

Plus one allow, in the same step as #4:

5. **`pemc-management-plan` can manage the matching lock file** — `s3:PutObject` on the `.tflock` counterpart of that same canary key must succeed, then the probe cleans it up with `s3:DeleteObject`. This is what makes #4 meaningful: the role isn't just denied everything on the state bucket, it's denied state writes specifically while retaining the lock-file management it actually needs.

## The canary bucket dependency

Probe #3 needs a key that's known to exist — `pemc-plan`'s `ReadOnlyAccess` grants `s3:ListBucket`, so a missing key returns 404 regardless of whether `s3:GetObject` itself would be denied, which would make the probe pass for the wrong reason. `woofle-pemc-lp-canary/canary.txt` is provisioned by `aws_s3_object.lp_canary` in `live/sandbox/_bootstrap` for exactly this purpose. If that stack hasn't been applied, the probe fails loudly with instructions to apply it first, rather than silently passing on a meaningless 404.

## Scope

Proves these five specific boundaries, on every PR, for as long as these two roles exist under these names. It does not prove:

- **Anything outside these probes** — the identity policies may grant other permissions (e.g. the run-bucket writes, or `pemc-management-apply`'s broader grants) that aren't exercised by an inverted assertion here. Absence of a probe is not evidence of absence of a permission.
