# Verification: enforcement levels and exemptions

## Claim

The policy repo's `policies/enforcement.yaml` and `exemptions.yaml` decide what a finding does. A `deny` finding fails the plan, a `warn` finding is shown and does not, and a valid exemption moves a finding to Exempted. An expired exemption stops waiving its finding. An invalid exemption makes the gate exit 2, so the plan fails with the reason in the PR comment.

## Why it holds

1. The rules always report. `evaluate.py` looks each finding up in the enforcement table, so changing a level doesn't touch Rego.
2. Exemptions live in the policy repo. Granting one takes a reviewed change there plus a pin bump here.
3. `evaluate.py` validates `exemptions.yaml` on every run, and any invalid entry is exit 2. Only a blocking finding is exit 1.

## Verification

Each test was run manually on PRs, on 21-10-2026 (UTC). The policy repo's YAML was changed through a PR there, then `.policy-version` was bumped to the merge commit. Every finding is `aws.ebs.encryption_required` on `aws_ebs_volume.scratch` in `live/sandbox/ap-south-1/storage`.

**A valid exemption**. Expiry 2026-11-05. Plan green, `1 exempted`, and the comment had one Exempted row: `exempted until 2026-11-05: Throwaway volume for the test`.

**An expired exemption**. Expiry 2026-10-20, the day before the run. Exit 1, plan red. The volume was under Blocking, plus a Warnings row: `expired exemption: expired 2026-10-20, now counts as a normal finding`.

**An expiry too far out**. Expiry 2027-10-20. Exit 2, plan red: `exemption 1: expires 2027-10-20 is more than 90 days away (latest allowed 2027-01-19)`.

**A non-exemptable policy**. Added an exemption for `common.input.schema_valid`. Exit 2, plan red: `exemption 2: common.input.schema_valid is not exemptable`.

**A `warn` level**. Set the policy to `warn` with no exemptions. Plan green, `0 blocking, 1 warnings`, and the volume was under Warnings.

## Scope

Proves these behaviours on the pipeline as it stood when tested. It does not prove (TODO):

- **The main-branch plan job.** Every test ran on a PR.
- **The 7-day expiry note, the unused-exemption note or the `off` level.** None was run in the pipeline. The policy repo's tests cover them.