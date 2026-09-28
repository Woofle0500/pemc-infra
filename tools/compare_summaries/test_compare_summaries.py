import json
from pathlib import Path

import pytest

import compare_summaries as cs


def write_summary(path: Path, changes: list[dict]) -> Path:
    path.write_text(json.dumps({"changes": changes}), encoding="utf-8")
    return path


def entry(address: str, kind: str) -> dict:
    return {"address": address, "actions": [], "kind": kind}


def run(tmp_path, reviewed_changes, current_changes) -> tuple[int, str]:
    reviewed = write_summary(tmp_path / "reviewed.json", reviewed_changes)
    current = write_summary(tmp_path / "current.json", current_changes)
    argv = ["--reviewed", str(reviewed), "--current", str(current)]

    code = cs.main(argv)
    return code


def test_identical_summaries_exit_zero(tmp_path, capsys):
    changes = [entry("aws_s3_bucket.a", "add"), entry("aws_iam_role.b", "change")]

    code = run(tmp_path, changes, changes)

    assert code == 0


def test_same_set_different_order_exits_zero(tmp_path):
    reviewed = [entry("aws_s3_bucket.a", "add"), entry("aws_iam_role.b", "change")]
    current = [entry("aws_iam_role.b", "change"), entry("aws_s3_bucket.a", "add")]

    code = run(tmp_path, reviewed, current)

    assert code == 0


@pytest.mark.parametrize("extra_side", ["reviewed", "current"])
def test_extra_entry_on_either_side_exits_one_and_names_address(
    tmp_path, capsys, extra_side
):
    base = [entry("aws_s3_bucket.a", "add")]
    extra = base + [entry("aws_iam_role.orphan", "destroy")]

    if extra_side == "reviewed":
        code = run(tmp_path, extra, base)
    else:
        code = run(tmp_path, base, extra)

    assert code == 1
    err = capsys.readouterr().err
    assert "aws_iam_role.orphan" in err


def test_same_address_different_kind_exits_one(tmp_path, capsys):
    reviewed = [entry("aws_iam_role.a", "change")]
    current = [entry("aws_iam_role.a", "replace")]

    code = run(tmp_path, reviewed, current)

    assert code == 1
    err = capsys.readouterr().err
    assert "aws_iam_role.a (change)" in err
    assert "in reviewed plan but not in main plan" in err
    assert "aws_iam_role.a (replace)" in err
    assert "in main plan but not in reviewed plan" in err


def test_entry_missing_kind_exits_nonzero(tmp_path):
    reviewed = [{"address": "aws_iam_role.a", "actions": ["update"]}]
    current = [entry("aws_iam_role.a", "change")]

    code = run(tmp_path, reviewed, current)

    assert code != 0


def test_entry_missing_address_exits_nonzero(tmp_path):
    reviewed = [{"actions": ["update"], "kind": "change"}]
    current = [entry("aws_iam_role.a", "change")]

    code = run(tmp_path, reviewed, current)

    assert code != 0
