# Reviewing a plan

Every stack's PR comment includes a truncated summary table and, underneath it, a `Full plan:` line with an `s3://` URI and the exact `aws s3 cp` command to fetch it. Use this when the summary table isn't enough to review a change (e.g. you need to see the actual before/after values `summarize_plan` deliberately never emits — see [tools/summarize_plan/README.md](../../tools/summarize_plan/README.md)).

## Fetching the plan

Copy the command straight from the PR comment. It looks like:

```bash
aws s3 cp s3://woofle-pemc-tf-run/plans/pr-<n>/runs/<run-id>/<run-attempt>/<stack-slug>/plan.txt - --profile management
```

`-` streams it to stdout instead of writing a file. Drop the `-` and add a filename if you'd rather save it locally.

## Permissions needed

The `management` CLI profile — configured via Identity Center SSO with the `PEMCAdmin` permission set (`AdministratorAccess`), see [naming.example.md](../naming.example.md). This isn't one of the CI roles; it's your own SSO session in the management account, which already has read access to the run bucket and `kms:Decrypt` on its CMK.

## Outside contributors can't do this

A PR from a fork gets a read-only `GITHUB_TOKEN` and no `id-token: write` — it never assumes an AWS role, so it can't reach the run bucket either during CI or afterward. Fetching the full plan requires an SSO session in the management account, which only trusted org members have. This is deliberate: `summarize_plan` redacts values and sensitive attributes specifically so the PR comment itself is safe to show to anyone (including fork contributors), while the full plan — which can contain real values — stays behind the same access boundary as everything else in the management account.
