#!/usr/bin/env python3
"""Regression tests for the attested Type IR to wire adapter."""

from __future__ import annotations

import copy
import os
import shutil
import tempfile
import unittest
from pathlib import Path
from types import SimpleNamespace

import schema_lock
import type_ir_adapter

ROOT = Path(__file__).parents[1]
CONSUMER_LOCK = ROOT / "schema" / "type-ir-consumer.lock.json"
OVERLAY = ROOT / "schema" / "fixtures" / "wire-record-shape.overlay.json"
SCHEMA = ROOT / "schema" / "fixtures" / "profile-1-converted-record.lock.json"
BINDING = ROOT / "schema" / "fixtures" / "profile-1-converted-record.ada-binding.json"
PROVENANCE = ROOT / "schema" / "fixtures" / "profile-1-converted-record.provenance.json"


class Type_IR_Adapter_Tests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        configured = os.environ.get("FLYOLOGY_TYPE_IR_ROOT")
        if configured is None:
            raise RuntimeError("FLYOLOGY_TYPE_IR_ROOT must name the reviewed Type IR checkout")
        cls.type_ir_root = Path(configured).resolve()
        cls.type_ir_path = cls.type_ir_root / "fixtures" / "wire-record-shape.json"
        cls.consumer = type_ir_adapter.load_consumer_lock(CONSUMER_LOCK)
        with type_ir_adapter.import_checker(cls.type_ir_root, cls.consumer) as checker:
            cls.checked = checker.load_checked(cls.type_ir_path, "fixture_shape")
        cls.overlay = type_ir_adapter.load_overlay(OVERLAY)

    def test_reviewed_fixture_reproduces_committed_pipeline_inputs(self) -> None:
        schema, binding, provenance = type_ir_adapter.adapt(
            self.type_ir_root,
            self.type_ir_path,
            OVERLAY,
            CONSUMER_LOCK,
            "fixture_shape",
        )
        self.assertEqual(schema, schema_lock.load(SCHEMA))
        self.assertEqual(binding, schema_lock.load(BINDING))
        self.assertEqual(provenance, schema_lock.load(PROVENANCE))
        self.assertEqual(schema["fingerprint"], binding["schema_fingerprint"])
        self.assertEqual(schema["fingerprint"], provenance["wire_schema_fingerprint"])

    def test_production_strict_rejects_fixture_provenance(self) -> None:
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "strict validation failed"):
            type_ir_adapter.adapt(
                self.type_ir_root,
                self.type_ir_path,
                OVERLAY,
                CONSUMER_LOCK,
                "strict",
            )

    def test_checker_and_schema_bytes_are_attested_before_import(self) -> None:
        with tempfile.TemporaryDirectory() as directory:
            copied = Path(directory) / "type-ir"
            (copied / "scripts").mkdir(parents=True)
            (copied / "schema").mkdir(parents=True)
            shutil.copy2(self.type_ir_root / self.consumer["checker"]["path"], copied / "scripts")
            shutil.copy2(self.type_ir_root / self.consumer["schema"]["path"], copied / "schema")
            checker = copied / self.consumer["checker"]["path"]
            checker.write_bytes(checker.read_bytes() + b"\n# drift\n")
            with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "expected .* found"):
                type_ir_adapter.import_checker(copied, self.consumer)

    def test_overlay_must_map_every_component_once_with_unique_tags(self) -> None:
        missing = copy.deepcopy(self.overlay)
        missing["fields"].pop()
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "every root component"):
            type_ir_adapter.lower_checked(self.checked, missing, self.consumer)

        duplicate = copy.deepcopy(self.overlay)
        duplicate["fields"][1]["tag"] = duplicate["fields"][0]["tag"]
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "tags must be unique"):
            type_ir_adapter.lower_checked(self.checked, duplicate, self.consumer)

    def test_overlay_bounds_cannot_override_known_structure(self) -> None:
        overlay = copy.deepcopy(self.overlay)
        overlay["fields"][1]["value"]["minimum"] = "-32767"
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "explicit wire bounds"):
            type_ir_adapter.lower_checked(self.checked, overlay, self.consumer)

    def test_predicate_and_use_site_constraint_are_rejected(self) -> None:
        predicate_document = copy.deepcopy(self.checked.document)
        signed = next(
            item
            for item in predicate_document["declarations"]
            if item["stable_id"] == "decl:wire_shape.signed_16#public"
        )
        signed["shape"]["predicate"]["value"]["value"] = True
        predicate_checked = SimpleNamespace(
            document=predicate_document,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "Known Boolean False"):
            type_ir_adapter.lower_checked(predicate_checked, self.overlay, self.consumer)

        constrained_document = copy.deepcopy(self.checked.document)
        signed_component = next(
            item
            for item in constrained_document["components"]
            if item["stable_id"] == "decl:wire_shape.public_record.signed#public"
        )
        signed_component["type"]["constraint"] = {"kind": "dynamic"}
        constrained_checked = SimpleNamespace(
            document=constrained_document,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "use-site constraints"):
            type_ir_adapter.lower_checked(constrained_checked, self.overlay, self.consumer)

    def test_semantic_fingerprint_is_an_exact_overlay_lock(self) -> None:
        overlay = copy.deepcopy(self.overlay)
        overlay["type_ir_semantic_fingerprint"] = "0" * 64
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "does not match"):
            type_ir_adapter.lower_checked(self.checked, overlay, self.consumer)

    def test_component_presentation_name_cannot_change_the_binding(self) -> None:
        document = copy.deepcopy(self.checked.document)
        document["components"][0]["name"] = "Different_Component"
        checked = SimpleNamespace(
            document=document,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "canonical component identity"):
            type_ir_adapter.lower_checked(checked, self.overlay, self.consumer)

    def test_boolean_lowering_requires_standard_boolean(self) -> None:
        document = copy.deepcopy(self.checked.document)
        boolean = next(
            item
            for item in document["declarations"]
            if item["stable_id"] == "decl:standard.boolean#public"
        )
        boolean["declaration_form"] = "derived"
        checked = SimpleNamespace(
            document=document,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "requires Standard.Boolean"):
            type_ir_adapter.lower_checked(checked, self.overlay, self.consumer)

        constrained = copy.deepcopy(document)
        boolean = next(
            item
            for item in constrained["declarations"]
            if item["stable_id"] == "decl:standard.boolean#public"
        )
        boolean["declaration_form"] = "type"
        boolean["shape"]["range"]["static_high"]["value"]["value"] = False
        constrained_checked = SimpleNamespace(
            document=constrained,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "Known Boolean True"):
            type_ir_adapter.lower_checked(constrained_checked, self.overlay, self.consumer)

    def test_optional_semantics_and_output_aliases_are_rejected(self) -> None:
        document = copy.deepcopy(self.checked.document)
        document["optional_features"] = ["vendor/feature"]
        document["extensions"] = {"vendor/feature": {}}
        checked = SimpleNamespace(
            document=document,
            profile=self.checked.profile,
            semantic_fingerprint=self.checked.semantic_fingerprint,
            source_sha256=self.checked.source_sha256,
        )
        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "optional Type IR semantics"):
            type_ir_adapter.lower_checked(checked, self.overlay, self.consumer)

        with self.assertRaisesRegex(type_ir_adapter.Adapter_Error, "must be distinct"):
            type_ir_adapter.validate_output_paths(
                [SCHEMA, SCHEMA, PROVENANCE],
                [self.type_ir_path, OVERLAY, CONSUMER_LOCK],
                self.type_ir_root,
            )


if __name__ == "__main__":
    unittest.main()
