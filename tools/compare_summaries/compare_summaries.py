#!/usr/bin/env python3
"""Compare two `summarize_plan` summary.json files by (address, kind).

Used on push to main to check that the plan a reviewer approved on the PR
still matches the plan that's about to apply. A resource being added or
dropped is a difference worth flagging, and so is the *kind* changing for
the same address -- a `change` that quietly became a `replace` is data
loss, not a formatting quirk, so it must not compare as equal.
"""

from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path
from typing import Any


class InvalidSummaryEntryError(RuntimeError):
    """Raised when a summary entry has no "address" or no "kind". Such an entry must never compare
    as equal to a current one, so this fails loudly instead of comparing
    None."""


def load_summary(path: Path) -> dict[str, Any]:
    with path.open("r", encoding="utf-8") as f:
        return json.load(f)


def change_set(summary: dict[str, Any]) -> set[tuple[str, str]]:
    """Return the set of (address, kind) pairs for a summary's changes."""
    pairs = set()
    for entry in summary.get("changes", []):
        if "address" not in entry or "kind" not in entry:
            raise InvalidSummaryEntryError(f"entry missing \"address\" or \"kind\": {entry!r}")
        pairs.add((entry["address"], entry["kind"]))
    return pairs


def format_diff(reviewed: set[tuple[str, str]], current: set[tuple[str, str]]) -> str:
    only_reviewed = sorted(reviewed - current)
    only_current = sorted(current - reviewed)

    lines = []
    if only_reviewed:
        lines.append("in reviewed plan but not in main plan:")
        for address, kind in only_reviewed:
            lines.append(f"  {address} ({kind})")
    if only_current:
        if lines:
            lines.append("")
        lines.append("in main plan but not in reviewed plan:")
        for address, kind in only_current:
            lines.append(f"  {address} ({kind})")
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
    except InvalidSummaryEntryError as exc:
        print(f"error: {exc}", file=sys.stderr)
        return 1

    if reviewed == current:
        return 0

    print(format_diff(reviewed, current), file=sys.stderr)
    return 1


if __name__ == "__main__":
    raise SystemExit(main())
