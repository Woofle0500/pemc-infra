# compare_summaries

Compares two `summarize_plan` `summary.json` files by `(address, kind)` and reports whether they describe the same set of resource changes. Used on push to main to check that the plan a reviewer approved on the PR still matches the plan that's about to apply.

## What counts as a match

The set of `(address, kind)` pairs from `--reviewed` and `--current` must be identical.

| Difference | Result |
|---|---|
| Same pairs, any order | Match — exit `0` |
| An address present on one side only | Mismatch — exit `1` |
| Same address, different `kind` | Mismatch — exit `1` |

A same-address, different-`kind` mismatch is the case that matters most: a `change` that quietly became a `replace` between review and apply is data loss, not a formatting quirk, so it must never compare as equal.

## On mismatch

Exits `1` and prints both directions of the diff to stderr, labeled so a human knows what to go look at:

- `in reviewed plan but not in main plan`
- `in main plan but not in reviewed plan`

## Invalid entries fail the run

Any summary entry missing `"address"` or `"kind"` raises `InvalidSummaryEntryError`, which the CLI turns into a non-zero exit and an `error:` line on stderr. This is deliberate: a summary written before `"kind"` existed, or otherwise malformed, must never silently compare as equal to a current one — better to fail the run than wave through a plan that was never actually compared.
