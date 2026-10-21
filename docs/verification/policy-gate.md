# Verification: the policy gate blocks a plan that breaks policy

## Claim

A pull request whose plan breaks a policy, or whose plan the gate cannot evaluate, fails the `Plan` check and shows the reason in the PR comment. On main, the same gate fails the plan job, so the apply job never runs. The gate never passes a plan it did not evaluate.

## Why it holds

1. `policy-gate.sh` exits 0 only if conftest ran, at least `MIN_POLICIES` policy packages produced a result, and there are no findings. Anything else is exit 1 (findings) or 2 (could not evaluate).
2. Each stack's plan job records the exit code as an artifact. The `Plan` check fails for any stack whose result is not `0`, including a missing one.
3. The policy repo is checked out at the commit in `.policy-version`, so a policy change reaches this pipeline only through a PR that changes that file.

## Verification

Each test was run manually on a PR, on 21-10-2026, and behaved as expected. Reviewed the plan jobs, the PR comment and the `Plan` check.

**A. A real violation.** Added an `aws_ebs_volume` with `encrypted = false` to the storage stack. The `Plan` check went red and the comment listed `aws.ebs.encryption_required` on `aws_ebs_volume.this`.

**B. A missing tag.** Removed `pemc:owner` from the stack's `default_tags`. The `Plan` check went red with one finding, `common.tagging.required_labels` on `module.storage.aws_s3_bucket.this`. The bucket was the only resource that can carry tags at that point; its S3 child resources have `labels_state` `unsupported`.

**C. Policies that can't be evaluated.** Two ways, both exit 2 with the `Plan` check red and the reason in the comment:
- Pointed the gate at an empty directory. Conftest rejected it: `Policy evaluation failed: ... no policies found in [./empty_dir]`.
- Deleted one policy package from the checked-out `policy/` folder, leaving 2 of the 3 required. The floor caught it: `Policy evaluation failed: only 2 policies evaluated, expected at least 3`.

**D. A bad pin.** Two cases, both with the plan job red and no PR comment posted or updated:
- `wrongsha123123`: the setup step failed with `.policy-version must hold a full 40-character commit SHA`.
- A well-formed 40-character SHA that does not exist (the real one with one character changed): the checkout failed with `not our ref <sha>`.

**E. Clean.** Removed the violation. The plan job and the `Plan` check were green and the comment said `No policy findings.`

## Scope

Proves these behaviours on the pipeline as it stood when tested. It does not prove:

- **The main-branch plan job.** All five tests ran on PRs. The same gate script and setup action run there, but failing the plan job and skipping the apply was not exercised.
