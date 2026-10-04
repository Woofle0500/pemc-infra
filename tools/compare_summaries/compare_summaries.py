#!/usr/bin/env python3
"""Compare two `summarize_plan` summary.json files by (address, kind,
actions) and by their counts.

Used on push to main to check that the plan a reviewer approved on the PR
still matches the plan that's about to apply. A resource being added or
dropped is a difference worth flagging, and so is the *kind* changing for
the same address -- a `change` that quietly became a `replace` is data
loss, not a formatting quirk, so it must not compare as equal. The action
order is compared too, since a replace is delete-then-create or
create-then-delete and the two behave differently.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


Change = tuple[str, str, tuple[str, ...]]


class InvalidSummaryEntryError(RuntimeError):
    """Raised when a summary, or one of its entries, is missing a required
    field ("changes", "counts", or an entry's "address", "kind" or
    "actions"). Such a summary must never compare as equal to a current one,
    so this fails loudly instead of comparing None or an empty default."""


def load_summary(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def change_set(summary: dict[str, Any]) -> set[Change]:
    """Return the set of (address, kind, actions) tuples for a summary's changes."""
    if not isinstance(summary.get("changes"), list):
        raise InvalidSummaryEntryError('summary missing "changes" list')
    changes = set()
    for entry in summary["changes"]:
        if "address" not in entry or "kind" not in entry or "actions" not in entry:
            raise InvalidSummaryEntryError(
                f"entry missing \"address\", \"kind\" or \"actions\": {entry!r}"
            )
        changes.add((entry["address"], entry["kind"], tuple(entry["actions"])))
    return changes


def counts_of(summary: dict[str, Any]) -> dict[str, int]:
    counts = summary.get("counts")
    if not isinstance(counts, dict):
        raise InvalidSummaryEntryError('summary missing "counts" object')
    return counts


def format_change(change: Change) -> str:
    address, kind, actions = change
    return f"{address} ({kind}) [{', '.join(actions)}]"


def format_diff(
    reviewed: set[Change],
    current: set[Change],
    reviewed_counts: dict[str, int],
    current_counts: dict[str, int],
) -> str:
    only_reviewed = sorted(reviewed - current)
    only_current = sorted(current - reviewed)

    lines = []
    if only_reviewed:
        lines.append("in reviewed plan but not in main plan:")
        lines.extend(f"  {format_change(c)}" for c in only_reviewed)
    if only_current:
        if lines:
            lines.append("")
        lines.append("in main plan but not in reviewed plan:")
        lines.extend(f"  {format_change(c)}" for c in only_current)
    if reviewed_counts != current_counts:
        if lines:
            lines.append("")
        lines.append("counts differ (reviewed -> main):")
        for key in sorted(reviewed_counts.keys() | current_counts.keys()):
            before, after = reviewed_counts.get(key, 0), current_counts.get(key, 0)
            if before != after:
                lines.append(f"  {key}: {before} -> {after}")
    return "\n".join(lines)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--reviewed", required=True, type=Path, help="Path to the PR's summary.json"
    )
    parser.add_argument(
        "--current", required=True, type=Path, help="Path to main branch's summary.json"
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)

    reviewed_summary = load_summary(args.reviewed)
    current_summary = load_summary(args.current)

    try:
        reviewed = change_set(reviewed_summary)
        current = change_set(current_summary)
        reviewed_counts = counts_of(reviewed_summary)
        current_counts = counts_of(current_summary)
    except InvalidSummaryEntryError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if reviewed == current and reviewed_counts == current_counts:
        return 0

    print(
        format_diff(reviewed, current, reviewed_counts, current_counts),
        file=sys.stderr,
    )
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
