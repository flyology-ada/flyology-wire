#!/usr/bin/env python3
"""Regression tests for the closed schema-lock projection."""

from __future__ import annotations

import copy
import json
import re
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

import schema_lock

FIXTURE = Path(__file__).parents[1] / "schema" / "fixtures" / "profile-1-record.lock.json"
OLDER_FIXTURE = FIXTURE.with_name("profile-1-record-v1.lock.json")
FUTURE_FIXTURE = FIXTURE.with_name("profile-1-record-v3.lock.json")
SIGNED_FIXTURE = FIXTURE.with_name("profile-1-signed-record.lock.json")
DEFAULTED_FIXTURE = FIXTURE.with_name("profile-1-defaulted-record.lock.json")
SEQUENCE_FIXTURE = FIXTURE.with_name("profile-1-sequence-record.lock.json")
OPTIONAL_FIXTURE = FIXTURE.with_name("profile-1-optional-record.lock.json")
BYTES_FIXTURE = FIXTURE.with_name("profile-1-bytes-record.lock.json")
TEXT_FIXTURE = FIXTURE.with_name("profile-1-text-record.lock.json")
ENUMERATION_FIXTURE = FIXTURE.with_name("profile-1-enumeration-record.lock.json")
VARIANT_FIXTURE = FIXTURE.with_name("profile-1-variant-record.lock.json")
PROJECTION = FIXTURE.with_name("profile-1-record.projection.json")
DIGEST = FIXTURE.with_name("profile-1-record.sha256")
ADA_CODEC = FIXTURE.parents[2] / "tests" / "src" / "profile_1_test_codec.ads"


def signed(minimum: str, maximum: str) -> dict[str, object]:
    return {"kind": "signed", "maximum": maximum, "minimum": minimum}


def complete_document() -> dict[str, object]:
    document: dict[str, object] = {
        "family_id": "51000000000000000000000000000000",
        "fingerprint": "0" * 64,
        "lock_format": "flyology-wire-schema-lock",
        "lock_version": 1,
        "profile_id": 1,
        "root": {
            "fields": [
                {"presence": "required", "tag": 1, "value": {"kind": "boolean"}},
                {"presence": "required", "tag": 2, "value": signed("-4", "7")},
                {
                    "presence": "required",
                    "tag": 3,
                    "value": {
                        "kind": "enumeration",
                        "reserved_tags": [],
                        "values": [{"tag": 1}, {"tag": 9}],
                    },
                },
                {
                    "presence": "required",
                    "tag": 4,
                    "value": {
                        "construction_lower_bound": "1",
                        "kind": "bytes",
                        "maximum_octets": "16",
                        "minimum_octets": "0",
                    },
                },
                {
                    "presence": "required",
                    "tag": 5,
                    "value": {
                        "construction_lower_bound": "1",
                        "encoding": "utf-8",
                        "kind": "text",
                        "maximum_octets": "32",
                        "maximum_scalars": "32",
                        "minimum_octets": "0",
                        "minimum_scalars": "0",
                    },
                },
                {
                    "presence": "required",
                    "tag": 6,
                    "value": {
                        "dimensions": [
                            {
                                "construction_lower_bound": "1",
                                "maximum_count": "4",
                                "minimum_count": "0",
                            },
                            {
                                "construction_lower_bound": "-2",
                                "maximum_count": "3",
                                "minimum_count": "3",
                            },
                        ],
                        "element": {"kind": "boolean"},
                        "kind": "sequence",
                    },
                },
                {
                    "presence": "required",
                    "tag": 7,
                    "value": {"kind": "optional", "value": signed("-1", "1")},
                },
                {
                    "presence": "required",
                    "tag": 8,
                    "value": {
                        "alternatives": [
                            {
                                "tag": 2,
                                "value": {"fields": [], "kind": "record", "reserved_tags": []},
                            },
                            {
                                "tag": 5,
                                "value": {
                                    "fields": [
                                        {
                                            "presence": "required",
                                            "tag": 1,
                                            "value": {"kind": "boolean"},
                                        }
                                    ],
                                    "kind": "record",
                                    "reserved_tags": [],
                                },
                            },
                        ],
                        "kind": "variant",
                        "reserved_tags": [],
                    },
                },
                {
                    "default_wire": "00",
                    "presence": "defaulted",
                    "tag": 9,
                    "value": {"kind": "boolean"},
                },
            ],
            "kind": "record",
            "reserved_tags": [],
        },
        "schema_revision": 2,
    }
    document["fingerprint"] = schema_lock.schema_fingerprint(document)
    return document


class Schema_Lock_Tests(unittest.TestCase):
    def test_committed_fixture(self) -> None:
        for fixture in (
            OLDER_FIXTURE,
            FIXTURE,
            FUTURE_FIXTURE,
            SIGNED_FIXTURE,
            DEFAULTED_FIXTURE,
            SEQUENCE_FIXTURE,
            OPTIONAL_FIXTURE,
            BYTES_FIXTURE,
            TEXT_FIXTURE,
            ENUMERATION_FIXTURE,
            VARIANT_FIXTURE,
        ):
            with self.subTest(fixture=fixture.name):
                schema_lock.validate_lock(schema_lock.load(fixture))

    def test_committed_golden_projection(self) -> None:
        document = schema_lock.load(FIXTURE)
        self.assertEqual(schema_lock.canonical_projection(document), PROJECTION.read_bytes().rstrip(b"\n"))
        self.assertEqual(schema_lock.schema_fingerprint(document), DIGEST.read_text(encoding="ascii").strip())

    def test_ada_fixture_uses_the_lock_fingerprint(self) -> None:
        source = ADA_CODEC.read_text(encoding="utf-8")
        matches = re.findall(r"Fingerprint_From_Bytes\s*\(\s*\[(.*?)\]\s*\)", source, re.DOTALL)
        actual = [
            bytes(int(value, 16) for value in re.findall(r"16#([0-9A-F]{2})#", match)).hex()
            for match in matches
        ]
        expected = [
            schema_lock.load(fixture)["fingerprint"]
            for fixture in (FIXTURE, OLDER_FIXTURE, FUTURE_FIXTURE)
        ]
        self.assertEqual(actual, expected)

    def test_every_profile_1_shape(self) -> None:
        schema_lock.validate_lock(complete_document())

    def test_object_spelling_does_not_change_projection(self) -> None:
        original = complete_document()
        reordered = json.loads(json.dumps(original, sort_keys=False))
        reordered = dict(reversed(list(reordered.items())))
        self.assertEqual(
            schema_lock.canonical_projection(original), schema_lock.canonical_projection(reordered)
        )

    def test_source_metadata_is_not_a_lock_member(self) -> None:
        document = complete_document()
        document["source_name"] = "Example.Value"
        with self.assertRaisesRegex(schema_lock.Lock_Error, "extra=.*source_name"):
            schema_lock.validate_lock(document)

    def test_field_tags_must_increase(self) -> None:
        document = complete_document()
        fields = document["root"]["fields"]
        fields[1]["tag"] = fields[0]["tag"]
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "strictly increasing"):
            schema_lock.validate_lock(document)

    def test_reserved_tags_are_ordered_and_inactive(self) -> None:
        for reserved, message in (([11, 10], "strictly increasing"), ([1], "is active")):
            with self.subTest(reserved=reserved):
                document = complete_document()
                document["root"]["reserved_tags"] = reserved
                document["fingerprint"] = schema_lock.schema_fingerprint(document)
                with self.assertRaisesRegex(schema_lock.Lock_Error, message):
                    schema_lock.validate_lock(document)

    def test_enum_and_variant_tags_share_the_29_bit_domain(self) -> None:
        document = complete_document()
        document["root"]["fields"][2]["value"]["values"][1]["tag"] = (
            schema_lock.MAX_VALUE_TAG
        )
        document["root"]["fields"][7]["value"]["alternatives"][1]["tag"] = (
            schema_lock.MAX_VALUE_TAG
        )
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        schema_lock.validate_lock(document)

        for field_index, member in ((2, "values"), (7, "alternatives")):
            with self.subTest(member=member):
                out_of_range = copy.deepcopy(document)
                out_of_range["root"]["fields"][field_index]["value"][member][1]["tag"] = (
                    schema_lock.MAX_VALUE_TAG + 1
                )
                out_of_range["fingerprint"] = schema_lock.schema_fingerprint(out_of_range)
                with self.assertRaisesRegex(schema_lock.Lock_Error, "1 .. 536870911"):
                    schema_lock.validate_lock(out_of_range)

    def test_decimal_is_normalized(self) -> None:
        document = complete_document()
        document["root"]["fields"][1]["value"]["minimum"] = "-0"
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "normalized decimal"):
            schema_lock.validate_lock(document)

    def test_numeric_text_and_construction_depth_are_bounded(self) -> None:
        document = complete_document()
        document["root"]["fields"][3]["value"]["construction_lower_bound"] = str(
            schema_lock.I64_MAX + 1
        )
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "construction lower bound exceeds"):
            schema_lock.validate_lock(document)

        document = complete_document()
        document["root"]["fields"][1]["value"]["maximum"] = "1" * 21
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "numeric domain"):
            schema_lock.validate_lock(document)

        nested: dict[str, object] = {"kind": "boolean"}
        for _ in range(schema_lock.MAX_SCHEMA_DEPTH + 1):
            nested = {"kind": "optional", "value": nested}
        document = complete_document()
        document["root"] = nested
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "schema nesting exceeds"):
            schema_lock.validate_lock(document)

    def test_fingerprint_mismatch_fails(self) -> None:
        document = complete_document()
        document["schema_revision"] = 3
        with self.assertRaisesRegex(schema_lock.Lock_Error, "expected"):
            schema_lock.validate_lock(document)

    def test_duplicate_json_key_fails(self) -> None:
        with self.assertRaisesRegex(schema_lock.Lock_Error, "duplicate object key"):
            schema_lock.pairs_object([("kind", "boolean"), ("kind", "record")])

    def test_variant_payload_must_be_record(self) -> None:
        document = complete_document()
        variant = document["root"]["fields"][7]["value"]
        variant["alternatives"][0]["value"] = {"kind": "boolean"}
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "payload must be a record"):
            schema_lock.validate_lock(document)

    def test_default_bytes_are_lowercase_whole_octets(self) -> None:
        for invalid in ("0", "0A"):
            with self.subTest(invalid=invalid):
                document = copy.deepcopy(complete_document())
                document["root"]["fields"][8]["default_wire"] = invalid
                document["fingerprint"] = schema_lock.schema_fingerprint(document)
                with self.assertRaisesRegex(schema_lock.Lock_Error, "lowercase whole-octet"):
                    schema_lock.validate_lock(document)

    def test_default_bytes_must_encode_the_declared_value(self) -> None:
        document = complete_document()
        document["root"]["fields"][8]["default_wire"] = "02"
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "Boolean must be exactly"):
            schema_lock.validate_lock(document)

    def test_static_maximum_is_checked(self) -> None:
        document = complete_document()
        sequence = document["root"]["fields"][5]["value"]
        sequence["dimensions"][0]["maximum_count"] = str(schema_lock.U64_MAX)
        sequence["dimensions"][1]["maximum_count"] = "2"
        sequence["dimensions"][1]["minimum_count"] = "0"
        document["fingerprint"] = schema_lock.schema_fingerprint(document)
        with self.assertRaisesRegex(schema_lock.Lock_Error, "exceeds Byte_Count"):
            schema_lock.validate_lock(document)

    def test_zero_fingerprint_is_reserved(self) -> None:
        document = complete_document()
        document["fingerprint"] = "0" * 64
        with self.assertRaisesRegex(schema_lock.Lock_Error, "nonzero"):
            schema_lock.validate_lock(document)

    def test_integral_fields_reject_json_floats(self) -> None:
        for member in ("lock_version", "profile_id"):
            with self.subTest(member=member):
                document = complete_document()
                document[member] = 1.0
                document["fingerprint"] = schema_lock.schema_fingerprint(document)
                with self.assertRaisesRegex(schema_lock.Lock_Error, "must be integer 1"):
                    schema_lock.validate_lock(document)

    def test_non_json_numeric_constant_fails_to_load(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "invalid.json"
            path.write_text('{"value": NaN}', encoding="utf-8")
            with self.assertRaisesRegex(schema_lock.Lock_Error, "non-JSON numeric constant"):
                schema_lock.load(path)

    def test_set_fingerprint_accepts_a_missing_member(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "template.json"
            document = complete_document()
            document.pop("fingerprint")
            path.write_text(json.dumps(document), encoding="utf-8")
            result = subprocess.run(
                [sys.executable, str(Path(schema_lock.__file__)), "--set-fingerprint", str(path)],
                check=True,
                capture_output=True,
                text=True,
            )
            generated = json.loads(result.stdout, object_pairs_hook=schema_lock.pairs_object)
            schema_lock.validate_lock(generated)

    def test_canonical_default_decoder_covers_every_shape(self) -> None:
        fields = complete_document()["root"]["fields"]
        encodings = {
            0: "01",
            1: "01",
            2: "09",
            3: "dead",
            4: "f09f92a9",
            5: "0203010001010100010101000101",
            6: "010101",
            7: "0200",
        }
        for index, encoded in encodings.items():
            with self.subTest(kind=fields[index]["value"]["kind"]):
                schema_lock.validate_encoded_value(fields[index]["value"], encoded, "$.default")

    def test_default_text_rejects_invalid_utf8(self) -> None:
        text = complete_document()["root"]["fields"][4]["value"]
        with self.assertRaisesRegex(schema_lock.Lock_Error, "not canonical UTF-8"):
            schema_lock.validate_encoded_value(text, "80", "$.default")


if __name__ == "__main__":
    unittest.main()
