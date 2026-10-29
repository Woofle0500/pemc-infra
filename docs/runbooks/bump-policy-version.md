# Bumping the policy version

`.policy-version` pins the pemc-policy commit the policy gate runs against. The weekly "Policy pin is behind" issue says when a newer release exists.

## Steps

1. **Read the changelog** between the current and the new tag, in [pemc-policy's CHANGELOG.md](https://github.com/Woofle0500/pemc-policy/blob/main/CHANGELOG.md). The issue lists the sections.
2. **Get the commit SHA** of the new tag (not the tag object's SHA):

   ```bash
   git ls-remote https://github.com/Woofle0500/pemc-policy.git 'refs/tags/vX.Y.Z' 'refs/tags/vX.Y.Z^{}' | tail -n 1
   ```

3. **Open a PR that changes only `.policy-version`**, to that full SHA. The gate refuses a SHA that isn't on pemc-policy main or has no `vX.Y.Z` tag.
4. **Read every stack's policy findings** in the PR comment. The comment starts with `policies: vX.Y.Z`. Anything newly blocking needs one of:
   - a fix in this repo
   - an exemption, which lives in pemc-policy and so means another release
   - a decision not to adopt this release yet. Close the PR and leave the issue open.
5. **Merge once it's green.**

## Rolling back

Revert the PR.
