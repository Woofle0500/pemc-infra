import json
from pathlib import Path

import pytest

import summarize_plan as sp

FIXTURE_PLAN = Path(__file__).parent / "fixtures" / "plan.json"


@pytest.fixture
def plan():
    return sp.load_plan(FIXTURE_PLAN)


@pytest.fixture
def summary(plan):
    return sp.build_summary(plan)


def test_no_op_and_data_source_reads_are_dropped(summary):
    addresses = {c["address"] for c in summary["changes"]}
    assert "aws_iam_role.unchanged" not in addresses
    assert "data.aws_iam_policy_document.example" not in addresses


def test_counts_match_fixture(summary):
    assert summary["counts"] == {
        "add": 1,
        "change": 1,
        "destroy": 1,
        "replace": 1,
        "forget": 1,
        "import": 1,
        "move": 1,
    }


def test_changes_are_sorted_by_address(summary):
    addresses = [c["address"] for c in summary["changes"]]
    assert addresses == sorted(addresses)


def test_summary_entries_only_contain_address_actions_and_kind(summary):
    for entry in summary["changes"]:
        assert set(entry.keys()) == {"address", "actions", "kind"}


@pytest.mark.parametrize(
    ("address", "expected_actions"),
    [
        ("aws_s3_bucket.new_bucket", ["create"]),
        ("aws_iam_policy.boundary", ["update"]),
        ("aws_s3_bucket.old_bucket", ["delete"]),
        ("aws_iam_role.replaced", ["delete", "create"]),
    ],
)
def test_each_resource_has_expected_actions(summary, address, expected_actions):
    entry = next(c for c in summary["changes"] if c["address"] == address)
    assert entry["actions"] == expected_actions


def test_sensitive_attribute_is_excluded_from_changed_attributes(plan):
    change = next(
        rc["change"]
        for rc in plan["resource_changes"]
        if rc["address"] == "aws_iam_policy.boundary"
    )
    attrs = sp.changed_attributes(change)
    assert attrs == ["description"]
    assert "policy" not in attrs


def test_replace_reports_changed_attribute_names(plan):
    change = next(
        rc["change"]
        for rc in plan["resource_changes"]
        if rc["address"] == "aws_iam_role.replaced"
    )
    assert sp.changed_attributes(change) == ["name"]


def test_comment_body_never_leaks_sensitive_values(plan, summary):
    body = sp.build_comment_body(plan, summary)
    assert "old description" not in body
    assert "new description" not in body
    assert "old" not in body.lower().replace("old_bucket", "").replace(
        "old-role-name", ""
    )
    assert "Statement" not in body
    assert "`policy`" not in body
    assert "`description`" in body
    assert "aws_iam_role.unchanged" not in body


def test_comment_body_reports_plan_totals(plan, summary):
    body = sp.build_comment_body(plan, summary)
    assert (
        "1 to add, 1 to change, 1 to destroy, 1 to replace, 1 to forget, 1 to import, 1 to move." in body
    )


def test_forget_is_reported(summary):
    entry = next(
        c for c in summary["changes"] if c["address"] == "aws_s3_bucket.forgotten"
    )
    assert entry["kind"] == "forget"
    assert summary["counts"]["forget"] == 1


def test_import_is_reported(summary):
    entry = next(
        c for c in summary["changes"] if c["address"] == "aws_iam_role.imported"
    )
    assert entry["kind"] == "import"
    assert entry["actions"] == ["no-op"]
    assert summary["counts"]["import"] == 1


def test_rename_via_previous_address_is_reported_as_move(summary):
    entry = next(
        c for c in summary["changes"] if c["address"] == "aws_iam_role.renamed"
    )
    assert entry["kind"] == "move"
    assert entry["actions"] == ["no-op"]
    assert summary["counts"]["move"] == 1


def test_unrecognized_action_raises_unhandled_action_error():
    plan = {
        "resource_changes": [
            {
                "address": "aws_s3_bucket.mystery",
                "change": {
                    "actions": ["frobnicate"],
                    "before": None,
                    "after": None,
                    "before_sensitive": False,
                    "after_sensitive": False,
                },
            }
        ]
    }
    with pytest.raises(sp.UnhandledActionError):
        sp.build_summary(plan)


def test_cli_exits_non_zero_for_unrecognized_action(tmp_path):
    plan_path = tmp_path / "plan.json"
    plan_path.write_text(
        json.dumps(
            {
                "resource_changes": [
                    {
                        "address": "aws_s3_bucket.mystery",
                        "change": {
                            "actions": ["frobnicate"],
                            "before": None,
                            "after": None,
                            "before_sensitive": False,
                            "after_sensitive": False,
                        },
                    }
                ]
            }
        )
    )

    exit_code = sp.main(
        [
            str(plan_path),
            "--summary-json",
            str(tmp_path / "summary.json"),
            "--comment-body",
            str(tmp_path / "comment.md"),
            "--metadata-json",
            str(tmp_path / "metadata.json"),
        ]
    )

    assert exit_code != 0


def test_metadata_pulls_terraform_version_and_timestamp_from_plan(plan):
    args = sp.parse_args(
        [
            str(FIXTURE_PLAN),
            "--summary-json",
            "unused-summary.json",
            "--comment-body",
            "unused-comment.md",
            "--metadata-json",
            "unused-metadata.json",
            "--head-sha",
            "head123",
            "--merge-sha",
            "merge456",
            "--pr-number",
            "7",
            "--run-id",
            "999",
            "--run-attempt",
            "2",
            "--state-serial",
            "3",
        ]
    )
    metadata = sp.build_metadata(plan, args)
    assert metadata == {
        "head_sha": "head123",
        "merge_sha": "merge456",
        "pr_number": "7",
        "run_id": "999",
        "run_attempt": "2",
        "terraform_version": "1.15.9",
        "state_serial": "3",
        "timestamp": "2026-01-01T00:00:00Z",
    }


def test_end_to_end_writes_all_three_files_without_leaking_values(tmp_path):
    summary_path = tmp_path / "summary.json"
    comment_path = tmp_path / "comment.md"
    metadata_path = tmp_path / "metadata.json"

    exit_code = sp.main(
        [
            str(FIXTURE_PLAN),
            "--summary-json",
            str(summary_path),
            "--comment-body",
            str(comment_path),
            "--metadata-json",
            str(metadata_path),
            "--head-sha",
            "head123",
            "--pr-number",
            "7",
        ]
    )

    assert exit_code == 0

    summary = json.loads(summary_path.read_text())
    assert summary["counts"] == {
        "add": 1,
        "change": 1,
        "destroy": 1,
        "replace": 1,
        "forget": 1,
        "import": 1,
        "move": 1,
    }

    metadata = json.loads(metadata_path.read_text())
    assert metadata["head_sha"] == "head123"
    assert metadata["pr_number"] == "7"
    assert metadata["terraform_version"] == "1.15.9"

    comment_text = comment_path.read_text()
    assert "old description" not in comment_text
    assert "Statement" not in comment_text
