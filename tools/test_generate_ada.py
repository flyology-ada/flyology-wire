#!/usr/bin/env python3
"""Regression tests for the initial schema-lock-to-Ada backend."""

from __future__ import annotations

import json
import tempfile
import unittest
from pathlib import Path

import generate_ada
import schema_diff
import schema_lock

ROOT = Path(__file__).parents[1]
SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-record.lock.json"
BINDING = ROOT / "schema" / "fixtures" / "profile-1-record.ada-binding.json"
GENERATED = ROOT / "tests" / "generated"
SIGNED_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-signed-record.lock.json"
SIGNED_BINDING = ROOT / "schema" / "fixtures" / "profile-1-signed-record.ada-binding.json"
DEFAULTED_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-defaulted-record.lock.json"
DEFAULTED_BINDING = ROOT / "schema" / "fixtures" / "profile-1-defaulted-record.ada-binding.json"
SEQUENCE_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-sequence-record.lock.json"
SEQUENCE_BINDING = ROOT / "schema" / "fixtures" / "profile-1-sequence-record.ada-binding.json"
OPTIONAL_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-optional-record.lock.json"
OPTIONAL_BINDING = ROOT / "schema" / "fixtures" / "profile-1-optional-record.ada-binding.json"
BYTES_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-bytes-record.lock.json"
BYTES_BINDING = ROOT / "schema" / "fixtures" / "profile-1-bytes-record.ada-binding.json"
TEXT_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-text-record.lock.json"
TEXT_BINDING = ROOT / "schema" / "fixtures" / "profile-1-text-record.ada-binding.json"
ENUMERATION_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-enumeration-record.lock.json"
ENUMERATION_BINDING = ROOT / "schema" / "fixtures" / "profile-1-enumeration-record.ada-binding.json"
VARIANT_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-variant-record.lock.json"
VARIANT_BINDING = ROOT / "schema" / "fixtures" / "profile-1-variant-record.ada-binding.json"
OLDER_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-record-v1.lock.json"
OLDER_APPROVAL = ROOT / "schema" / "fixtures" / "profile-1-v1-to-v2.approval.json"
FUTURE_SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-record-v3.lock.json"
FUTURE_APPROVAL = ROOT / "schema" / "fixtures" / "profile-1-v3-to-v2.approval.json"


def inputs() -> tuple[dict[str, object], dict[str, object]]:
    return schema_lock.load(SCHEMA), schema_lock.load(BINDING)


class Ada_Generator_Tests(unittest.TestCase):
    def test_committed_output_is_current_and_bounded(self) -> None:
        cases = (
            (SCHEMA, BINDING, [(OLDER_SCHEMA, OLDER_APPROVAL), (FUTURE_SCHEMA, FUTURE_APPROVAL)]),
            (SIGNED_SCHEMA, SIGNED_BINDING, []),
            (DEFAULTED_SCHEMA, DEFAULTED_BINDING, []),
            (SEQUENCE_SCHEMA, SEQUENCE_BINDING, []),
            (OPTIONAL_SCHEMA, OPTIONAL_BINDING, []),
            (BYTES_SCHEMA, BYTES_BINDING, []),
            (TEXT_SCHEMA, TEXT_BINDING, []),
            (ENUMERATION_SCHEMA, ENUMERATION_BINDING, []),
            (VARIANT_SCHEMA, VARIANT_BINDING, []),
        )
        bodies: dict[str, str] = {}
        for schema_path, binding_path, pairs in cases:
            schema = schema_lock.load(schema_path)
            binding = schema_lock.load(binding_path)
            fields = generate_ada.validate_binding(binding, schema)
            compatible = generate_ada.validate_compatible_writers(schema, fields, pairs)
            base = binding["package_name"].lower()
            expected = {
                f"{base}.ads": generate_ada.render_spec(schema, binding, fields, compatible),
                f"{base}.adb": generate_ada.render_body(schema, binding, fields, compatible),
            }
            bodies[base] = expected[f"{base}.adb"]
            for name, content in expected.items():
                with self.subTest(name=name):
                    self.assertEqual((GENERATED / name).read_text(encoding="utf-8"), content)
                    self.assertLessEqual(max(map(len, content.splitlines())), 110)
        unsigned = bodies["generated_profile_1_test_codec"]
        self.assertIn("Interfaces.Unsigned_64'First", unsigned)
        self.assertIn("Interfaces.Unsigned_64'Last", unsigned)
        self.assertIn("Compatibility.Classify", unsigned)
        self.assertIn("Candidate.Enabled := False", unsigned)
        self.assertIn("Ignored_Writer_Tag_3", unsigned)
        defaulted = bodies["generated_profile_1_defaulted_test_codec"]
        self.assertIn("if Item.Enabled /= False then", defaulted)
        self.assertIn("if Candidate.Enabled = False then", defaulted)
        self.assertIn("if not Seen_Enabled then", defaulted)
        sequence = bodies["generated_profile_1_sequence_test_codec"]
        self.assertIn("procedure Measure_Items_Value", sequence)
        self.assertIn("for Element of Item.Items loop", sequence)
        self.assertIn("Profile.Read_Length_Delimited", sequence)
        self.assertIn("for Element of Candidate.Items loop", sequence)
        optional = bodies["generated_profile_1_optional_test_codec"]
        self.assertIn("if Item.Has_Number then", optional)
        self.assertIn("Candidate.Has_Number := True", optional)
        self.assertNotIn("not Seen_Number then", optional)
        byte_fields = bodies["generated_profile_1_bytes_test_codec"]
        self.assertIn("Profile.Write_Octets", byte_fields)
        self.assertIn("Profile.Read_Octets", byte_fields)
        self.assertIn("procedure Validate_For_Visit", byte_fields)
        self.assertIn("Profile.Visit_Extent (Visit_Data)", byte_fields)
        text = bodies["generated_profile_1_text_test_codec"]
        self.assertIn("Profile.Validate_UTF_8 (Item.UTF_8", text)
        self.assertIn("UTF_8_Scalar_Count > 3", text)
        self.assertIn("Profile.Visit_Extent (Visit_UTF_8)", text)
        enumeration = bodies["generated_profile_1_enum_test_codec"]
        self.assertIn("function Encoded_Shade_Tag", enumeration)
        self.assertIn("when Profile_1_Enumeration_Test_Types.Red", enumeration)
        self.assertIn("case Raw_Shade is", enumeration)
        variant = bodies["generated_profile_1_variant_test_codec"]
        self.assertIn("procedure Measure_Kind_Payload", variant)
        self.assertIn("Profile.Write_Length_Delimited", variant)
        self.assertIn("case Raw_Kind_Tag is", variant)
        self.assertIn("Candidate.Kind := Profile_1_Variant_Test_Types.Flag_Choice", variant)

    def test_compatibility_approval_is_exact_and_unique(self) -> None:
        schema, binding = inputs()
        fields = generate_ada.validate_binding(binding, schema)
        compatible = generate_ada.validate_compatible_writers(
            schema, fields, [(FUTURE_SCHEMA, FUTURE_APPROVAL), (OLDER_SCHEMA, OLDER_APPROVAL)]
        )
        self.assertEqual([entry["schema"]["schema_revision"] for entry in compatible], [1, 3])

        with self.assertRaisesRegex(generate_ada.Generator_Error, "unique"):
            generate_ada.validate_compatible_writers(
                schema, fields, [(OLDER_SCHEMA, OLDER_APPROVAL), (OLDER_SCHEMA, OLDER_APPROVAL)]
            )

        approval = schema_lock.load(OLDER_APPROVAL)
        approval["diff_fingerprint"] = "0" * 64
        report = schema_diff.directional_diff(schema_lock.load(OLDER_SCHEMA), schema)
        with self.assertRaisesRegex(schema_diff.Diff_Error, "fingerprint"):
            schema_diff.validate_approval(report, schema, approval)

    def test_defaulted_ignored_field_is_rejected_until_byte_equality_is_generated(self) -> None:
        schema, binding = inputs()
        fields = generate_ada.validate_binding(binding, schema)
        writer = schema_lock.load(FUTURE_SCHEMA)
        writer["root"]["fields"][2]["presence"] = "defaulted"
        writer["root"]["fields"][2]["default_wire"] = ""
        writer["fingerprint"] = schema_lock.schema_fingerprint(writer)
        schema_lock.validate_lock(writer)
        report = schema_diff.directional_diff(writer, schema)
        approval = {
            "approval_format": schema_diff.APPROVAL_FORMAT,
            "approval_version": 1,
            "diff_fingerprint": schema_diff.report_fingerprint(report),
            "reader_fingerprint": schema["fingerprint"],
            "resolutions": [{"action": "ignore_writer_field", "path": "$.root.field[3]"}],
            "writer_fingerprint": writer["fingerprint"],
        }
        with tempfile.TemporaryDirectory() as directory:
            writer_path = Path(directory) / "writer.json"
            approval_path = Path(directory) / "approval.json"
            writer_path.write_text(json.dumps(writer), encoding="utf-8")
            approval_path.write_text(json.dumps(approval), encoding="utf-8")
            with self.assertRaisesRegex(generate_ada.Generator_Error, "defaulted ignored"):
                generate_ada.validate_compatible_writers(
                    schema, fields, [(writer_path, approval_path)]
                )

    def test_binding_is_closed_and_bound_to_exact_schema(self) -> None:
        schema, binding = inputs()
        binding["extra"] = True
        with self.assertRaisesRegex(generate_ada.Generator_Error, "closed keys"):
            generate_ada.validate_binding(binding, schema)

        schema, binding = inputs()
        binding["schema_fingerprint"] = "f" * 64
        with self.assertRaisesRegex(generate_ada.Generator_Error, "does not match"):
            generate_ada.validate_binding(binding, schema)

        schema, binding = inputs()
        binding["binding_version"] = True
        with self.assertRaisesRegex(generate_ada.Generator_Error, "version"):
            generate_ada.validate_binding(binding, schema)

    def test_ada_names_fail_closed(self) -> None:
        for member, value in (("package_name", "end"), ("value_type", "Pkg.Value;Drop")):
            with self.subTest(member=member):
                schema, binding = inputs()
                binding[member] = value
                with self.assertRaisesRegex(generate_ada.Generator_Error, "Ada"):
                    generate_ada.validate_binding(binding, schema)

        schema, binding = inputs()
        binding["fields"][1]["ada_component"] = "code"
        with self.assertRaisesRegex(generate_ada.Generator_Error, "duplicates"):
            generate_ada.validate_binding(binding, schema)

    def test_binding_must_cover_supported_fields_in_tag_order(self) -> None:
        schema, binding = inputs()
        binding["fields"].reverse()
        with self.assertRaisesRegex(generate_ada.Generator_Error, "strictly increasing"):
            generate_ada.validate_binding(binding, schema)

        schema, binding = inputs()
        schema["root"]["fields"][1]["presence"] = "optional"
        schema["fingerprint"] = schema_lock.schema_fingerprint(schema)
        binding["schema_fingerprint"] = schema["fingerprint"]
        binding["fields"][1]["ada_present_component"] = "Has_Enabled"
        fields = generate_ada.validate_binding(binding, schema)
        self.assertEqual(fields[1]["present_component"], "Has_Enabled")

    def test_signed_scalar_uses_zigzag_primitives(self) -> None:
        schema = schema_lock.load(SIGNED_SCHEMA)
        binding = schema_lock.load(SIGNED_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        body = generate_ada.render_body(schema, binding, fields)
        self.assertIn("Profile.ZigZag_Encode (Item.Count)", body)
        self.assertIn("Profile.Write_Signed", body)
        self.assertIn("Profile.Read_Signed", body)

    def test_sequence_binding_is_rank_one_and_uses_distinct_components(self) -> None:
        schema = schema_lock.load(SEQUENCE_SCHEMA)
        binding = schema_lock.load(SEQUENCE_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        self.assertEqual(fields[0]["kind"], "sequence")

        schema["root"]["fields"][0]["value"]["dimensions"].append(
            {
                "construction_lower_bound": "1",
                "maximum_count": "2",
                "minimum_count": "0",
            }
        )
        schema["fingerprint"] = schema_lock.schema_fingerprint(schema)
        binding["schema_fingerprint"] = schema["fingerprint"]
        with self.assertRaisesRegex(generate_ada.Generator_Error, "rank one"):
            generate_ada.validate_binding(binding, schema)

        schema = schema_lock.load(SEQUENCE_SCHEMA)
        binding = schema_lock.load(SEQUENCE_BINDING)
        binding["fields"][0]["ada_length_component"] = "Items"
        with self.assertRaisesRegex(generate_ada.Generator_Error, "duplicates"):
            generate_ada.validate_binding(binding, schema)

    def test_byte_binding_is_bounded_closed_and_observer_scoped(self) -> None:
        schema = schema_lock.load(BYTES_SCHEMA)
        binding = schema_lock.load(BYTES_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        self.assertTrue(generate_ada.borrowed_observer_enabled(fields))
        self.assertEqual(fields[1]["kind"], "bytes")

        binding["fields"][1]["ada_bytes"] = "distinct_array"
        with self.assertRaisesRegex(generate_ada.Generator_Error, "stream_element_array"):
            generate_ada.validate_binding(binding, schema)

        binding = schema_lock.load(BYTES_BINDING)
        binding["fields"][1]["borrowed_observer"] = 1
        with self.assertRaisesRegex(generate_ada.Generator_Error, "Boolean"):
            generate_ada.validate_binding(binding, schema)

        binding = schema_lock.load(BYTES_BINDING)
        binding["fields"][1]["extra"] = True
        with self.assertRaisesRegex(generate_ada.Generator_Error, "closed bytes keys"):
            generate_ada.validate_binding(binding, schema)

    def test_text_binding_requires_explicit_utf_8_octet_storage(self) -> None:
        schema = schema_lock.load(TEXT_SCHEMA)
        binding = schema_lock.load(TEXT_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        self.assertEqual(fields[0]["kind"], "text")
        self.assertTrue(generate_ada.borrowed_observer_enabled(fields))

        binding["fields"][0]["ada_text"] = "string"
        with self.assertRaisesRegex(generate_ada.Generator_Error, "utf_8_stream_element_array"):
            generate_ada.validate_binding(binding, schema)

    def test_enumeration_binding_maps_every_explicit_tag_to_one_literal(self) -> None:
        schema = schema_lock.load(ENUMERATION_SCHEMA)
        binding = schema_lock.load(ENUMERATION_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        self.assertEqual(
            [(item["tag"], item["name"]) for item in fields[0]["literals"]],
            [(1, "Red"), (9, "Green")],
        )

        binding["fields"][0]["ada_literals"].reverse()
        with self.assertRaisesRegex(generate_ada.Generator_Error, "tag order"):
            generate_ada.validate_binding(binding, schema)

        binding = schema_lock.load(ENUMERATION_BINDING)
        binding["fields"][0]["ada_literals"][1]["ada_literal"] = (
            "Profile_1_Enumeration_Test_Types.Red"
        )
        with self.assertRaisesRegex(generate_ada.Generator_Error, "duplicates"):
            generate_ada.validate_binding(binding, schema)

    def test_variant_binding_maps_selectors_and_required_scalar_payloads(self) -> None:
        schema = schema_lock.load(VARIANT_SCHEMA)
        binding = schema_lock.load(VARIANT_BINDING)
        fields = generate_ada.validate_binding(binding, schema)
        self.assertEqual(fields[0]["kind"], "variant")
        self.assertEqual(
            [(alternative["tag"], alternative["name"]) for alternative in fields[0]["alternatives"]],
            [(1, "Number_Choice"), (9, "Flag_Choice")],
        )

        binding["fields"][0]["ada_alternatives"].reverse()
        with self.assertRaisesRegex(generate_ada.Generator_Error, "tag order"):
            generate_ada.validate_binding(binding, schema)

        binding = schema_lock.load(VARIANT_BINDING)
        binding["fields"][0]["ada_alternatives"][1]["fields"][0]["ada_component"] = "Number"
        with self.assertRaisesRegex(generate_ada.Generator_Error, "duplicates"):
            generate_ada.validate_binding(binding, schema)

    def test_declaring_unit_must_be_explicit(self) -> None:
        schema, binding = inputs()
        binding["with_units"] = ["Another_Unit"]
        with self.assertRaisesRegex(generate_ada.Generator_Error, "declaring unit"):
            generate_ada.validate_binding(binding, schema)

    def test_larger_record_output_remains_line_bounded(self) -> None:
        schema, binding = inputs()
        for tag in range(3, 9):
            schema["root"]["fields"].append(
                {"presence": "required", "tag": tag, "value": {"kind": "boolean"}}
            )
            binding["fields"].append(
                {
                    "ada_component": f"Additional_Component_{tag}",
                    "ada_scalar": "boolean",
                    "tag": tag,
                }
            )
        schema["fingerprint"] = schema_lock.schema_fingerprint(schema)
        binding["schema_fingerprint"] = schema["fingerprint"]
        schema_lock.validate_lock(schema)
        fields = generate_ada.validate_binding(binding, schema)
        output = generate_ada.render_spec(schema, binding, fields) + generate_ada.render_body(
            schema, binding, fields
        )
        self.assertLessEqual(max(map(len, output.splitlines())), 110)


if __name__ == "__main__":
    unittest.main()
