#!/usr/bin/env python3
"""Summarize a `terraform show -json` plan into a redacted summary, PR
comment body, and run metadata file.

Never reads or emits: computed/after values, full before/after blobs, or
any attribute Terraform marked sensitive. Only resource addresses, action
verbs, and (for changed resources) the *names* of attributes that differ.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
from pathlib import Path
from typing import Any

NOOP_ACTIONS = {"no-op", "read"}
KINDS = {
    frozenset({"create"}):           "add",
    frozenset({"update"}):           "change",
    frozenset({"delete"}):           "destroy",
    frozenset({"delete", "create"}): "replace",
    frozenset({"forget"}):           "forget",
}


def load_plan(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def is_relevant(change: dict[str, Any]) -> bool:
    """Returns True if the change.actions is not a no-op/read action"""
    return not set(change["actions"]).issubset(NOOP_ACTIONS)


class UnhandledActionError(RuntimeError):
    """Raised when a resource change's actions aren't recognized, so the plan cannot be safely summarized."""


def sensitive_keys(change: dict[str, Any]) -> set[str] | bool:
    """Return the set of top-level attribute names Terraform marked
    sensitive, or True if the whole before/after object is sensitive."""
    keys: set[str] = set()
    for field in ("before_sensitive", "after_sensitive"):
        marker = change.get(field)
        if marker is True:
            return True
        if isinstance(marker, dict):
            keys.update(k for k, v in marker.items() if v)
    return keys


def changed_attributes(change: dict[str, Any]) -> list[str]:
    """Top-level attribute names that differ between before/after, with
    sensitive attribute names excluded entirely."""
    before = change.get("before") or {}
    after = change.get("after") or {}
    if not isinstance(before, dict) or not isinstance(after, dict):
        return []

    sensitive = sensitive_keys(change)
    if sensitive is True:
        return []

    names = set(before.keys()) | set(after.keys())
    changed = sorted(
        name
        for name in names
        if name not in sensitive and before.get(name) != after.get(name)
    )
    return changed


def build_summary(plan: dict[str, Any]) -> dict[str, Any]:
    counts = {
        "add": 0,
        "change": 0,
        "destroy": 0,
        "replace": 0,
        "forget": 0,
        "import": 0,
        "move": 0,
    }
    changes = []

    for rc in plan.get("resource_changes", []):
        change = rc["change"]

        if change.get("importing"):
            kind = "import"
        elif rc.get("previous_address") and rc["previous_address"] != rc["address"]:
            kind = "move"
        elif not is_relevant(change):
            continue
        else:
            kind = KINDS.get(frozenset(change["actions"])) # None if action is not recognised.

        if kind is None:
            raise UnhandledActionError(
                f"unrecognized action(s) {change['actions']!r} for resource {rc['address']!r}; refusing to summarize an incomplete plan"
            )
        counts[kind] += 1
        changes.append({
            "address": rc["address"], 
            "actions": list(change["actions"]),
            "kind": kind
        })

    changes.sort(key=lambda c: c["address"])

    return {"changes": changes, "counts": counts}


ACTION_LABELS = {
    "add": "create",
    "change": "update",
    "destroy": "destroy",
    "replace": "replace",
    "forget": "forget",
    "import": "import",
    "move": "move",
}


def build_comment_body(plan: dict[str, Any], summary: dict[str, Any]) -> str:
    counts = summary["counts"]
    lines = [
        "### Terraform plan summary",
        "",
        f"Plan: {counts['add']} to add, {counts['change']} to change, "
        f"{counts['destroy']} to destroy, {counts['replace']} to replace, "
        f"{counts['forget']} to forget, {counts['import']} to import, "
        f"{counts['move']} to move.",
        "",
    ]

    if not summary["changes"]:
        lines.append("No resource changes.")
        return "\n".join(lines) + "\n"

    changes_by_address = {
        rc["address"]: rc["change"] for rc in plan.get("resource_changes", [])
    }

    lines.append("| Resource | Action | Changed attributes |")
    lines.append("| --- | --- | --- |")

    for entry in summary["changes"]:
        address = entry["address"]
        actions = entry["actions"]
        kind = entry["kind"]
        label = ACTION_LABELS.get(kind, "/".join(actions))

        change = changes_by_address.get(address, {})
        attrs = changed_attributes(change) if kind in ("change", "replace") else []
        attrs_text = ", ".join(f"`{a}`" for a in attrs) if attrs else "-"

        lines.append(f"| `{address}` | {label} | {attrs_text} |")

    lines.append("")
    return "\n".join(lines) + "\n"


def build_metadata(plan: dict[str, Any], args: argparse.Namespace) -> dict[str, Any]:
    return {
        "head_sha": args.head_sha,
        "merge_sha": args.merge_sha,
        "pr_number": args.pr_number,
        "run_id": args.run_id,
        "run_attempt": args.run_attempt,
        "terraform_version": plan.get("terraform_version"),
        "state_serial": args.state_serial,
        "timestamp": plan.get("timestamp"),
    }


def write_json(path: Path, data: Any) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with path.open("w", encoding="utf-8") as f:
        json.dump(data, f, indent=2, sort_keys=True)
        f.write("\n")


def write_text(path: Path, text: str) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(text, encoding="utf-8")


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("plan_json", type=Path, help="Path to `terraform show -json` output")
    parser.add_argument(
        "--summary-json", type=Path, required=True, help="Output path for summary.json"
    )
    parser.add_argument(
        "--comment-body", type=Path, required=True, help="Output path for the PR comment body"
    )
    parser.add_argument(
        "--metadata-json", type=Path, required=True, help="Output path for metadata.json"
    )
    parser.add_argument(
        "--head-sha", default=os.environ.get("HEAD_SHA") or os.environ.get("GITHUB_SHA")
    )
    parser.add_argument("--merge-sha", default=os.environ.get("MERGE_SHA"))
    parser.add_argument("--pr-number", default=os.environ.get("PR_NUMBER"))
    parser.add_argument("--run-id", default=os.environ.get("GITHUB_RUN_ID"))
    parser.add_argument("--run-attempt", default=os.environ.get("GITHUB_RUN_ATTEMPT"))
    parser.add_argument("--state-serial", default=os.environ.get("STATE_SERIAL"))
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    plan = load_plan(args.plan_json)
    try:
        summary = build_summary(plan)
    except UnhandledActionError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1
    comment_body = build_comment_body(plan, summary)
    metadata = build_metadata(plan, args)

    write_json(args.summary_json, summary)
    write_text(args.comment_body, comment_body)
    write_json(args.metadata_json, metadata)

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
