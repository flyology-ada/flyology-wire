#!/usr/bin/env python3
"""Regression tests for directional schema diffs and approvals."""

from __future__ import annotations

import copy
import unittest
from pathlib import Path

import schema_diff
import schema_lock

FIXTURES = Path(__file__).parents[1] / "schema" / "fixtures"
OLDER = FIXTURES / "profile-1-record-v1.lock.json"
LOCAL = FIXTURES / "profile-1-record.lock.json"
FUTURE = FIXTURES / "profile-1-record-v3.lock.json"


def completed(document: dict[str, object]) -> dict[str, object]:
    document["fingerprint"] = schema_lock.schema_fingerprint(document)
    return document


class Schema_Diff_Tests(unittest.TestCase):
    def test_committed_reports_and_approvals(self) -> None:
        reader = schema_lock.load(LOCAL)
        cases = (
            (OLDER, "profile-1-v1-to-v2"),
            (FUTURE, "profile-1-v3-to-v2"),
        )
        for writer_path, name in cases:
            with self.subTest(name=name):
                report = schema_diff.directional_diff(schema_lock.load(writer_path), reader)
                expected = schema_lock.load(FIXTURES / f"{name}.diff.json")
                self.assertEqual(report, expected)
                approval = schema_lock.load(FIXTURES / f"{name}.approval.json")
                schema_diff.validate_approval(report, reader, approval)

    def test_family_history_is_monotonic(self) -> None:
        older = schema_lock.load(OLDER)
        local = schema_lock.load(LOCAL)
        future = schema_lock.load(FUTURE)
        self.assertEqual(schema_diff.evolution_issues(older, local), [])
        self.assertEqual(schema_diff.evolution_issues(local, future), [])

    def test_removed_tag_must_be_reserved_and_cannot_return(self) -> None:
        previous = schema_lock.load(LOCAL)
        removed = copy.deepcopy(previous)
        removed["schema_revision"] = 3
        removed["root"]["fields"].pop()
        completed(removed)
        self.assertEqual(
            schema_diff.evolution_issues(previous, removed),
            [{"code": "removed_tag_not_reserved", "path": "$.root.tag[2]"}],
        )
        removed["root"]["reserved_tags"] = [2]
        completed(removed)
        self.assertEqual(schema_diff.evolution_issues(previous, removed), [])
        reused = copy.deepcopy(removed)
        reused["schema_revision"] = 4
        reused["root"]["reserved_tags"] = []
        reused["root"]["fields"].append(
            {"presence": "required", "tag": 2, "value": {"kind": "boolean"}}
        )
        completed(reused)
        self.assertEqual(
            schema_diff.evolution_issues(removed, reused),
            [{"code": "reserved_tag_reused", "path": "$.root.tag[2]"}],
        )

    def test_writer_range_must_fit_reader(self) -> None:
        writer = schema_lock.load(LOCAL)
        reader = copy.deepcopy(writer)
        reader["root"]["fields"][0]["value"]["maximum"] = "100"
        completed(reader)
        report = schema_diff.directional_diff(writer, reader)
        self.assertEqual(
            report["incompatibilities"],
            [{"code": "writer_maximum_above_reader", "path": "$.root.field[1]"}],
        )

    def test_value_kind_change_requires_a_new_family(self) -> None:
        previous = schema_lock.load(LOCAL)
        current = copy.deepcopy(previous)
        current["schema_revision"] = 3
        current["root"]["fields"][0]["value"] = {"kind": "boolean"}
        completed(current)
        self.assertEqual(
            schema_diff.evolution_issues(previous, current),
            [{"code": "value_kind_changed_within_family", "path": "$.root.field[1]"}],
        )

    def test_presence_and_default_changes_fail_closed(self) -> None:
        writer = schema_lock.load(LOCAL)
        reader = copy.deepcopy(writer)
        reader_field = reader["root"]["fields"][1]
        reader_field["presence"] = "defaulted"
        reader_field["default_wire"] = "00"
        completed(reader)
        report = schema_diff.directional_diff(writer, reader)
        self.assertEqual(report["incompatibilities"][0]["code"], "field_presence_changed")

        writer = copy.deepcopy(reader)
        writer["root"]["fields"][1]["default_wire"] = "01"
        completed(writer)
        report = schema_diff.directional_diff(writer, reader)
        self.assertEqual(report["incompatibilities"][0]["code"], "field_default_changed")

    def test_approval_must_match_exact_diff_and_valid_default(self) -> None:
        writer = schema_lock.load(OLDER)
        reader = schema_lock.load(LOCAL)
        report = schema_diff.directional_diff(writer, reader)
        approval = schema_lock.load(FIXTURES / "profile-1-v1-to-v2.approval.json")
        approval["resolutions"][0]["default_wire"] = "02"
        with self.assertRaisesRegex(schema_lock.Lock_Error, "Boolean must be exactly"):
            schema_diff.validate_approval(report, reader, approval)

        approval = schema_lock.load(FIXTURES / "profile-1-v1-to-v2.approval.json")
        approval["resolutions"] = []
        with self.assertRaisesRegex(schema_diff.Diff_Error, "exactly match"):
            schema_diff.validate_approval(report, reader, approval)

    def test_structural_incompatibility_cannot_be_approved(self) -> None:
        writer = schema_lock.load(LOCAL)
        reader = copy.deepcopy(writer)
        reader["root"]["fields"][0]["value"] = {"kind": "boolean"}
        completed(reader)
        report = schema_diff.directional_diff(writer, reader)
        approval = {
            "approval_format": schema_diff.APPROVAL_FORMAT,
            "approval_version": 1,
            "diff_fingerprint": schema_diff.report_fingerprint(report),
            "reader_fingerprint": reader["fingerprint"],
            "resolutions": [],
            "writer_fingerprint": writer["fingerprint"],
        }
        with self.assertRaisesRegex(schema_diff.Diff_Error, "structural incompatibilities"):
            schema_diff.validate_approval(report, reader, approval)


if __name__ == "__main__":
    unittest.main()
