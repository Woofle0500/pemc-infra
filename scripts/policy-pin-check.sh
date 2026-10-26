#!/usr/bin/env bash
# Opens or updates an issue when .policy-version is behind the newest
# pemc-policy release, and closes it once the pin has caught up.
#
# usage: policy-pin-check.sh
#
# Run from the repo root. Needs git, python3 and an authenticated gh
# (GH_TOKEN, and GH_REPO if not run inside a checkout of the repo).
set -euo pipefail

policy_url=https://github.com/Woofle0500/pemc-policy.git
tag_re='^v[0-9]+\.[0-9]+\.[0-9]+$'
title_prefix="Policy pin is behind"

sha=$(tr -d '[:space:]' < .policy-version)

latest=$(git ls-remote --tags --refs "$policy_url" \
  | sed 's|.*refs/tags/||' | { grep -E "$tag_re" || true; } | sort -V | tail -n 1)
if [ -z "$latest" ]; then
  echo "::error::no release tags (vX.Y.Z) found on $policy_url"
  exit 1
fi

work=$(mktemp -d)
trap 'rm -rf "$work"' EXIT
git clone --quiet --no-checkout --filter=blob:none "$policy_url" "$work"

pinned=$(git -C "$work" tag --points-at "$sha" \
  | { grep -E "$tag_re" || true; } | sort -V | tail -n 1)
if [ -z "$pinned" ]; then
  echo "::error::.policy-version $sha has no release tag"
  exit 1
fi

existing=$(gh issue list --state open --search "\"$title_prefix\" in:title" \
  --json number,title --jq "map(select(.title | startswith(\"$title_prefix\")))[0].number // empty")

highest=$(printf '%s\n%s\n' "$pinned" "$latest" | sort -V | tail -n 1)
if [ "$pinned" = "$latest" ] || [ "$highest" = "$pinned" ]; then
  echo "pin is at $pinned, latest is $latest"
  if [ -n "$existing" ]; then
    gh issue close "$existing" --comment "The pin is now at $pinned."
  fi
  exit 0
fi

title="$title_prefix: $pinned → $latest"

sections=$(git -C "$work" show "$latest:CHANGELOG.md" 2>/dev/null \
  | python3 -c '
import re, sys
def ver(s):
    return tuple(int(x) for x in s.lstrip("v").split("."))
pinned, latest = ver(sys.argv[1]), ver(sys.argv[2])
for part in re.split(r"(?m)^(?=## )", sys.stdin.read()):
    m = re.match(r"## \[?v?(\d+\.\d+\.\d+)", part)
    if m and pinned < ver(m.group(1)) <= latest:
        print(part.rstrip() + "\n")
' "$pinned" "$latest" || true)

body=$(mktemp)
{
  echo "\`.policy-version\` pins pemc-policy $pinned (\`$sha\`). The latest release is $latest."
  echo
  echo "To update, set \`.policy-version\` to the full SHA of the new release:"
  echo
  # ^{} is git syntax for "dereference this tag to the commit it points at".
  echo "    git ls-remote $policy_url refs/tags/$latest^{}"
  echo
  echo "## Changes since $pinned"
  echo
  if [ -n "$sections" ]; then
    echo "$sections"
  else
    echo "No changelog entries found. See https://github.com/Woofle0500/pemc-policy/releases"
  fi
} > "$body"

if [ -n "$existing" ]; then
  gh issue edit "$existing" --title "$title" --body-file "$body"
  echo "updated issue #$existing"
else
  gh issue create --title "$title" --body-file "$body"
fi
