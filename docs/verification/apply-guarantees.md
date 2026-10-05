# Verification: the apply pipeline's guarantees

## Claim

The apply pipeline runs only for commits that came from a pull request, applies only after a human approves at the `sandbox-apply` gate, applies exactly the plan that was uploaded (from apply workflow's plan job), and surfaces any difference from the plan that was reviewed (from the PR).

## Why it holds

Each guarantee is structural, not procedural:

1. `resolve-pr` fails if the commit has no associated PR, and every stack job needs it.
2. The apply job runs in the `sandbox-apply` environment, which requires a reviewer.
3. The apply job verifies the sha256 of the downloaded `tfplan` against the digest the plan job computed, before it assumes the write-capable role.
4. The divergence check compares the reviewed PR summary against the one just produced, and reports the result in the run summary.

## Verification

Each test was run manually and behaved as expected.

**A. Rejection.** Merged a harmless change and rejected at the gate. The apply job did not run its steps and nothing changed in AWS.

**B. Divergence.** Opened a PR and let it plan. With the admin profile, downloaded its `latest/<slug>/summary.json`, modified one entry, uploaded it back to the same key, and merged. The divergence check reported `❌ FAILED`.

**C. Tampering.** Merged a harmless change. While the apply job was waiting, overwrote the `tfplan` object under `plans/main/...` with a different file using the admin profile, then approved. The apply aborted on `tfplan digest mismatch` and changed nothing.

**D. No PR.** Temporarily allowed a ruleset bypass, pushed one commit directly to main, then restored the ruleset. `resolve-pr` failed with `No pull request found for commit`, so no stack job ran.

## Scope

Proves these four behaviors on the pipeline as it stood when tested. It does not prove:

- **That divergence blocks anything.** By design the check warns and never fails the job; a reviewer has to read it.
- **Tampering outside the `tfplan` object.** The digest covers that file only; `plan.txt` and `summary.json` are not digest-checked.
