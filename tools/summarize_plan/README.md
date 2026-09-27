# summarize_plan

Summarizes a `terraform show -json` plan into a redacted `summary.json`, a PR comment body, and a `metadata.json` run record. Used by `_plan_stack.yaml` after every `terraform plan`.

## Never emits

- **Values.** No `before`/`after` contents, computed or otherwise — only resource addresses, action verbs, and (for changed resources) the *names* of the top-level attributes that differ.
- **Sensitive attribute names.** Any attribute Terraform marks sensitive (`before_sensitive`/`after_sensitive`) is excluded from the changed-attributes list entirely — not redacted, left out. If Terraform marks the whole before/after object sensitive, the changed-attributes list for that resource comes back empty.

This is what makes the PR comment safe to show on any PR, including from forks — see [docs/runbooks/review-a-plan.md](../../docs/runbooks/review-a-plan.md) for how a reviewer gets the unredacted plan instead.

## Actions handled

| Kind | When |
|---|---|
| `add` | `actions == ["create"]` |
| `change` | `actions == ["update"]` |
| `destroy` | `actions == ["delete"]` |
| `replace` | `actions == ["delete", "create"]` |
| `forget` | `actions == ["forget"]` |
| `import` | `change.importing` is set (checked before the no-op/read filter, so an otherwise no-op import isn't dropped) |
| `move` | `previous_address` differs from `address` (checked ahead of `import` and the no-op/read filter for the same reason) |

`no-op` and `read` actions are dropped as irrelevant, unless the change is actually an `import` or `move` in disguise (see above).

## Unknown actions fail the run

Any resource change whose `actions` don't match one of the kinds above raises `UnhandledActionError`, which the CLI turns into a non-zero exit and an `error:` line on stderr. This is deliberate: an unrecognized action means the plan can't be safely summarized, and silently skipping it would produce a summary that looks complete but isn't — better to fail the run than post a misleading comment.
