#!/usr/bin/env bash
# Policy gate: normalise a Terraform plan and check it against the policies.
#
# usage: policy-gate.sh <stack> <plan.json>
#
#   stack       the stack's path, recorded in the output as meta.stack.
#   plan.json   path to the plan, relative to the current directory or absolute.
#
# The policy repo is expected at $POLICY_DIR (default: $GITHUB_WORKSPACE/policy).
# Installs nothing: Python and conftest must already be set up
# (.github/actions/policy-gate-setup).
#
# Writes input.json, findings.json and findings.md to the current directory,
# wherever the script is run from.
#
# Exit codes are the evaluator's: 0 no findings, 1 findings, 2 couldn't
# evaluate. A normaliser failure is also 2.
set -euo pipefail

stack=${1:?usage: policy-gate.sh <stack> <plan.json>}
plan=${2:?usage: policy-gate.sh <stack> <plan.json>}
policy_dir=${POLICY_DIR:-${GITHUB_WORKSPACE:?GITHUB_WORKSPACE or POLICY_DIR must be set}/policy}

# stderr is captured, stdout goes to the file.
if ! err=$(python3 "$policy_dir/normalizer/normalize.py" "$plan" --stack "$stack" 2>&1 >input.json); then
  echo "$err" >&2
  printf 'Policy evaluation failed: normaliser failed: %s\n' "${err#error: }" > findings.md
  exit 2
fi

mkdir ./empty_dir

exec python3 "$policy_dir/normalizer/evaluate.py" input.json \
  --policies "./empty_dir" \
  --findings findings.json \
  --markdown findings.md
