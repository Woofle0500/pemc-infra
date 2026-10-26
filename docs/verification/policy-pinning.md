# Verification: policy pinning

## Claim

The plan only runs against a released pemc-policy: the commit in `.policy-version` must be on pemc-policy main and carry a `vX.Y.Z` tag. The plan comment and run summary name the release. A release tag can't be moved or deleted. A weekly job opens an issue when the pin falls behind the latest release.

## Why it holds

1. `policy-gate-setup` checks that the pinned SHA is an ancestor of `origin/main`, then that `git tag --points-at` returns a `^v[0-9]+\.[0-9]+\.[0-9]+$` tag. Either failure stops the job before the policy requirements are installed.
2. The pin is a SHA, not a tag name, so moving a tag can't change what runs.
3. The pemc-policy ruleset "Lock release versions" covers `refs/tags/v*` with `update`, `deletion` and `non_fast_forward` rules and no bypass actors.

## Verification

**An untagged commit on main.** `.policy-version` held `927358f` (#16, on pemc-policy main, no tag), commit `e31e588`. Plan red, the setup step failed with `.policy-version 927358f… has no release tag (vX.Y.Z) on pemc-policy. Pin a released commit.`

**The v1.0.0 commit.** Commit `a60b60c` set `.policy-version` to `275a16d`, the commit `v1.0.0` points at. Plan green, and the comment showed `policies: v1.0.0`.

**Moving the v1.0.0 tag.** Tried to force-push `v1.0.0` to another commit from the CLI. Refused by the tag ruleset.

Tests 1 and 2 were run on PR #36 on 26-10-2026 (UTC), as two commits on one branch. Test 3 was run with the CLI against pemc-policy.

## Not yet verified

- **The weekly pin check.** Needs a release newer than the pin. When one exists, run `policy-pin-check.yaml` and confirm an issue titled `Policy pin is behind: v1.0.0 → vX.Y.Z` opens with the changelog sections in between, and that a second run updates it instead of opening another.
- **Bumping to that release.** Follow [bump-policy-version.md](../runbooks/bump-policy-version.md) in a PR. Expect a green plan, `policies: vX.Y.Z` in the comment, and any findings from new warn rules under Warnings.
