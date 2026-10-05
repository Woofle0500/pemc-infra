# Approving an apply

Every push to main plans each stack again, then pauses at the `sandbox-apply` environment gate until a required reviewer approves. Stacks whose plan has no changes skip the gate.

## What you are deciding

Whether this plan, as it stands now, should be applied to the sandbox account. That's all.

You are **not** re-reviewing the code (that happened on the PR), and you are **not** checking that the plan file is intact (the apply job does that itself and aborts on a digest mismatch).

The divergence check warns but never blocks, so a `FAILED` or `UNVERIFIED` result is a decision for **you**.

## Reading the step summary

Open the run's summary. Per stack, the plan job writes:

| Line | Meaning | What to do |
|---|---|---|
| `Divergence check: ✅ PASSED` | Same resources and actions as the plan reviewed on the PR | Approve if the plan below looks right |
| `Divergence check: ❌ FAILED` | The plan differs from what was reviewed; the diff is listed | Read the diff, fetch the full plan, approve only if the difference is explained |
| `Divergence check: ⚠️ UNVERIFIED` | No reviewed plan found (missing or expired) | Treat as unreviewed: fetch the full plan and read all of it |

The summary is public, so it only gives the plan's S3 location and its `plan.txt` sha256, never its contents.

## Fetching plan.txt

Save the file, and compare its digest against the `plan.txt sha256` line in the summary before reading it:

```bash
aws s3 cp s3://woofle-pemc-tf-run/plans/main/<sha>/<run-id>/<run-attempt>/<stack-slug>/plan.txt plan.txt --profile management
sha256sum plan.txt
```

If the digest does not match the summary, do not read or trust the file, and reject the apply.

Permissions are the same as in [review-a-plan.md](review-a-plan.md).

## Approving or rejecting

In the UI: **Review deployments** on the run page.

Rejecting fails the apply job. Nothing is applied and AWS is untouched; the merged code stays on main, so fix forward or revert.
If a run has waited more than a few hours, use "Re-run all jobs" instead of approving. The saved plan is checked against the state serial, not against changes made in AWS since - meaning that the world may have changed due to manual changes for instance.