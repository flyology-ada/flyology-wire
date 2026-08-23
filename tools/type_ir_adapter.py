#!/usr/bin/env python3
"""Lower one checked Flyology Type IR record through a closed wire overlay."""

from __future__ import annotations

import argparse
import hashlib
import importlib.util
import json
import re
import shutil
import sys
import tempfile
from pathlib import Path, PurePosixPath
from types import ModuleType
from typing import Any

import generate_ada
import schema_lock

ROOT = Path(__file__).resolve().parents[1]
DEFAULT_CONSUMER_LOCK = ROOT / "schema" / "type-ir-consumer.lock.json"
LOWER_HEX_40 = re.compile(r"[0-9a-f]{40}\Z")
LOWER_HEX_64 = re.compile(r"[0-9a-f]{64}\Z")
I64_MIN = -(2**63)
I64_MAX = 2**63 - 1
U64_MAX = 2**64 - 1


class Adapter_Error(ValueError):
    """An attestation, Type IR, overlay, or lowering failure."""


class Attested_Checker:
    """Scoped access to a checker imported from attested dependency bytes."""

    def __init__(self, module: ModuleType, directory: tempfile.TemporaryDirectory[str]):
        self._module = module
        self._directory = directory

    def __enter__(self) -> Attested_Checker:
        return self

    def __exit__(self, *_: object) -> None:
        self._directory.cleanup()

    def load_checked(self, path: Path, profile: str) -> Any:
        return self._module.load_checked(path, profile)


def canonical_bytes(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True).encode(
        "ascii"
    )


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def require_object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict) or set(value) != keys:
        raise Adapter_Error(f"{path}: has incorrect closed keys")
    return value


def require_integer(value: Any, path: str, minimum: int, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not minimum <= value <= maximum:
        raise Adapter_Error(f"{path}: must be an integer in {minimum} .. {maximum}")
    return value


def require_hex(value: Any, path: str, pattern: re.Pattern[str]) -> str:
    if not isinstance(value, str) or pattern.fullmatch(value) is None:
        raise Adapter_Error(f"{path}: must be canonical lowercase hexadecimal")
    return value


def require_relative_path(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        raise Adapter_Error(f"{path}: must be a nonempty relative path")
    candidate = PurePosixPath(value)
    if candidate.is_absolute() or ".." in candidate.parts or candidate.as_posix() != value:
        raise Adapter_Error(f"{path}: must be a normalized repository-relative path")
    return value


def load_consumer_lock(path: Path) -> dict[str, Any]:
    lock = require_object(
        schema_lock.load(path),
        "$",
        {
            "checker",
            "commit",
            "consumer_format",
            "consumer_version",
            "ir_version",
            "repository",
            "required_features",
            "schema",
            "wire_fixture",
        },
    )
    if lock["consumer_format"] != "flyology-wire-type-ir-consumer-lock":
        raise Adapter_Error("$.consumer_format: is unsupported")
    if type(lock["consumer_version"]) is not int or lock["consumer_version"] != 1:
        raise Adapter_Error("$.consumer_version: must be integer 1")
    if type(lock["ir_version"]) is not int or lock["ir_version"] != 1:
        raise Adapter_Error("$.ir_version: must be integer 1")
    if lock["repository"] != "https://github.com/flyology-ada/flyology-type-ir":
        raise Adapter_Error("$.repository: is unsupported")
    require_hex(lock["commit"], "$.commit", LOWER_HEX_40)
    expected_features = [
        "ada-type-ir/core",
        "ada-type-ir/decimal-strings",
        "ada-type-ir/exact-variants",
        "ada-type-ir/graph-refs",
        "ada-type-ir/typed-shapes",
    ]
    if lock["required_features"] != expected_features:
        raise Adapter_Error("$.required_features: differs from the reviewed v1 feature set")
    for member in ("checker", "schema"):
        item = require_object(lock[member], f"$.{member}", {"path", "sha256"})
        require_relative_path(item["path"], f"$.{member}.path")
        require_hex(item["sha256"], f"$.{member}.sha256", LOWER_HEX_64)
    fixture = require_object(
        lock["wire_fixture"],
        "$.wire_fixture",
        {"path", "semantic_fingerprint", "source_sha256"},
    )
    require_relative_path(fixture["path"], "$.wire_fixture.path")
    require_hex(
        fixture["semantic_fingerprint"],
        "$.wire_fixture.semantic_fingerprint",
        LOWER_HEX_64,
    )
    require_hex(fixture["source_sha256"], "$.wire_fixture.source_sha256", LOWER_HEX_64)
    return lock


def attested_bytes(
    type_ir_root: Path, entry: dict[str, str], path: str
) -> tuple[Path, bytes]:
    root = type_ir_root.resolve()
    candidate = (root / entry["path"]).resolve()
    try:
        candidate.relative_to(root)
    except ValueError as error:
        raise Adapter_Error(f"{path}.path: escapes the Type IR root") from error
    try:
        content = candidate.read_bytes()
    except OSError as error:
        raise Adapter_Error(f"{candidate}: {error}") from error
    actual = sha256(content)
    if actual != entry["sha256"]:
        raise Adapter_Error(f"{path}.sha256: expected {entry['sha256']}, found {actual}")
    return candidate, content


def import_checker(type_ir_root: Path, lock: dict[str, Any]) -> Attested_Checker:
    _, schema_content = attested_bytes(type_ir_root, lock["schema"], "$.schema")
    checker_path, checker_content = attested_bytes(type_ir_root, lock["checker"], "$.checker")
    module_name = "flyology_wire_attested_type_ir_checker"
    temporary = tempfile.TemporaryDirectory(prefix="flyology-wire-type-ir-")
    attested_root = Path(temporary.name)
    copied_checker = attested_root / lock["checker"]["path"]
    copied_schema = attested_root / lock["schema"]["path"]
    copied_checker.parent.mkdir(parents=True)
    copied_schema.parent.mkdir(parents=True)
    copied_checker.write_bytes(checker_content)
    copied_schema.write_bytes(schema_content)
    fixture_directory = type_ir_root.resolve() / "fixtures"
    if fixture_directory.is_dir():
        shutil.copytree(fixture_directory, attested_root / "fixtures")
    specification = importlib.util.spec_from_file_location(module_name, copied_checker)
    if specification is None or specification.loader is None:
        temporary.cleanup()
        raise Adapter_Error(f"{checker_path}: cannot create an import specification")
    module = importlib.util.module_from_spec(specification)
    previous = sys.modules.get(module_name)
    previous_bytecode = sys.dont_write_bytecode
    sys.modules[module_name] = module
    sys.dont_write_bytecode = True
    try:
        specification.loader.exec_module(module)
    except Exception as error:
        temporary.cleanup()
        raise Adapter_Error(f"{checker_path}: cannot import attested checker: {error}") from error
    finally:
        sys.dont_write_bytecode = previous_bytecode
        if previous is None:
            sys.modules.pop(module_name, None)
        else:
            sys.modules[module_name] = previous
    if not callable(getattr(module, "load_checked", None)):
        temporary.cleanup()
        raise Adapter_Error(f"{checker_path}: has no load_checked entry point")
    return Attested_Checker(module, temporary)


def load_overlay(path: Path) -> dict[str, Any]:
    overlay = require_object(
        schema_lock.load(path),
        "$",
        {
            "family_id",
            "fields",
            "overlay_format",
            "overlay_version",
            "package_name",
            "profile_id",
            "reserved_tags",
            "root_declaration_id",
            "schema_revision",
            "type_ir_semantic_fingerprint",
        },
    )
    if overlay["overlay_format"] != "flyology-wire-type-ir-overlay":
        raise Adapter_Error("$.overlay_format: is unsupported")
    if type(overlay["overlay_version"]) is not int or overlay["overlay_version"] != 1:
        raise Adapter_Error("$.overlay_version: must be integer 1")
    if overlay["profile_id"] != 1:
        raise Adapter_Error("$.profile_id: only canonical Profile 1 is supported")
    require_integer(overlay["schema_revision"], "$.schema_revision", 1, schema_lock.U32_MAX)
    require_hex(overlay["type_ir_semantic_fingerprint"], "$.type_ir_semantic_fingerprint", LOWER_HEX_64)
    generate_ada.require_expanded_name(overlay["package_name"], "$.package_name")
    if not isinstance(overlay["root_declaration_id"], str):
        raise Adapter_Error("$.root_declaration_id: must be a semantic declaration ID")
    if not isinstance(overlay["fields"], list) or not overlay["fields"]:
        raise Adapter_Error("$.fields: must be a nonempty array")
    if not isinstance(overlay["reserved_tags"], list):
        raise Adapter_Error("$.reserved_tags: must be an array")
    return overlay


def known_boolean(fact: Any, expected: bool, path: str) -> None:
    if not isinstance(fact, dict) or fact.get("status") != "known":
        raise Adapter_Error(f"{path}: must be Known")
    value = fact.get("value")
    if not isinstance(value, dict) or value != {"kind": "boolean", "value": expected}:
        raise Adapter_Error(f"{path}: must be Known Boolean {expected}")


def known_decimal(fact: Any, path: str) -> str:
    if not isinstance(fact, dict) or fact.get("status") != "known":
        raise Adapter_Error(f"{path}: must be Known")
    value = fact.get("value")
    if not isinstance(value, dict) or set(value) != {"kind", "value"}:
        raise Adapter_Error(f"{path}: must be a Known decimal integer")
    if value["kind"] != "decimal_integer" or not isinstance(value["value"], str):
        raise Adapter_Error(f"{path}: must be a Known decimal integer")
    if schema_lock.DECIMAL.fullmatch(value["value"]) is None:
        raise Adapter_Error(f"{path}: has a noncanonical decimal integer")
    return value["value"]


def declaration_unit(declaration: dict[str, Any], path: str) -> str:
    location = declaration.get("location")
    if not isinstance(location, dict):
        raise Adapter_Error(f"{path}.location: is missing")
    unit = generate_ada.require_expanded_name(location.get("unit_name"), f"{path}.location.unit_name")
    display = generate_ada.require_identifier(declaration.get("display_name"), f"{path}.display_name")
    canonical = declaration.get("canonical_name")
    if canonical != f"{unit}.{display}".lower():
        raise Adapter_Error(f"{path}: initial lowering requires a direct compilation-unit declaration")
    if declaration.get("stable_id") != f"decl:{canonical}#public":
        raise Adapter_Error(f"{path}: initial lowering rejects generic or noncanonical identity")
    return unit


def expanded_type_name(declaration: dict[str, Any], path: str) -> str:
    return f"{declaration_unit(declaration, path)}.{declaration['display_name']}"


def ada_identifier_from_canonical(value: Any, path: str) -> str:
    canonical = generate_ada.require_identifier(value, path)
    return "_".join(part.capitalize() for part in canonical.split("_"))


def validate_safe_declaration(declaration: dict[str, Any], path: str) -> None:
    if declaration.get("view") != "public":
        raise Adapter_Error(f"{path}.view: initial lowering requires the public view")
    facts = declaration.get("facts")
    if not isinstance(facts, dict):
        raise Adapter_Error(f"{path}.facts: is missing")
    expected = {
        "abstract": False,
        "class_wide": False,
        "contains_access": False,
        "contains_controlled": False,
        "controlled": False,
        "definite": True,
        "limited": False,
        "protected": False,
        "tagged": False,
        "task": False,
    }
    for name, value in expected.items():
        known_boolean(facts.get(name), value, f"{path}.facts.{name}")


def validate_boolean_type(declaration: dict[str, Any], path: str) -> None:
    validate_safe_declaration(declaration, path)
    if (
        declaration.get("stable_id") != "decl:standard.boolean#public"
        or declaration.get("canonical_name") != "standard.boolean"
        or declaration.get("display_name") != "Boolean"
        or declaration.get("declaration_form") != "type"
        or declaration.get("references") != []
        or declaration.get("related_view_ids") != []
    ):
        raise Adapter_Error(f"{path}: initial Boolean lowering requires Standard.Boolean")
    if declaration_unit(declaration, path) != "Standard":
        raise Adapter_Error(f"{path}: initial Boolean lowering requires Standard.Boolean")
    shape = declaration.get("shape")
    if not isinstance(shape, dict) or shape.get("kind") != "boolean_scalar":
        raise Adapter_Error(f"{path}.shape: does not resolve to Standard.Boolean")
    known_boolean(shape.get("predicate"), False, f"{path}.shape.predicate")
    scalar_range = shape.get("range")
    if not isinstance(scalar_range, dict) or scalar_range.get("kind") != "scalar_range":
        raise Adapter_Error(f"{path}.shape.range: must be the Standard.Boolean range")
    known_boolean(scalar_range.get("predicate"), False, f"{path}.shape.range.predicate")
    known_boolean(scalar_range.get("staticness"), True, f"{path}.shape.range.staticness")
    known_boolean(scalar_range.get("static_low"), False, f"{path}.shape.range.static_low")
    known_boolean(scalar_range.get("static_high"), True, f"{path}.shape.range.static_high")


def validate_integer_type(
    declaration: dict[str, Any], lowering: dict[str, Any], path: str
) -> str:
    validate_safe_declaration(declaration, path)
    if declaration.get("declaration_form") != "type":
        raise Adapter_Error(f"{path}.declaration_form: initial integer lowering requires a named type")
    if declaration.get("references") != [] or declaration.get("related_view_ids") != []:
        raise Adapter_Error(f"{path}: initial integer lowering rejects derived or alternate views")
    shape = declaration.get("shape")
    if not isinstance(shape, dict):
        raise Adapter_Error(f"{path}.shape: is missing")
    expected_shape = "signed_scalar" if lowering["kind"] == "signed" else "modular_scalar"
    if shape.get("kind") != expected_shape:
        raise Adapter_Error(f"{path}.shape.kind: does not match the wire lowering")
    known_boolean(shape.get("predicate"), False, f"{path}.shape.predicate")
    scalar_range = shape.get("range")
    if not isinstance(scalar_range, dict) or scalar_range.get("kind") != "scalar_range":
        raise Adapter_Error(f"{path}.shape.range: must be an exact scalar range")
    known_boolean(scalar_range.get("predicate"), False, f"{path}.shape.range.predicate")
    known_boolean(scalar_range.get("staticness"), True, f"{path}.shape.range.staticness")
    low = known_decimal(scalar_range.get("static_low"), f"{path}.shape.range.static_low")
    high = known_decimal(scalar_range.get("static_high"), f"{path}.shape.range.static_high")
    if (low, high) != (lowering["minimum"], lowering["maximum"]):
        raise Adapter_Error(f"{path}.shape.range: differs from the explicit wire bounds")
    low_value = int(low)
    high_value = int(high)
    if lowering["kind"] == "signed":
        if not I64_MIN <= low_value <= high_value <= I64_MAX:
            raise Adapter_Error(f"{path}.shape.range: exceeds the signed Profile 1 domain")
    else:
        if not 0 <= low_value <= high_value <= U64_MAX:
            raise Adapter_Error(f"{path}.shape.range: exceeds the unsigned Profile 1 domain")
        modulus = int(known_decimal(shape.get("modulus"), f"{path}.shape.modulus"))
        if low_value != 0 or high_value != modulus - 1:
            raise Adapter_Error(f"{path}.shape: modular range and modulus disagree")
    return expanded_type_name(declaration, path)


def validate_field_overlay(value: Any, path: str) -> dict[str, Any]:
    field = require_object(value, path, {"component_id", "presence", "tag", "value"})
    if not isinstance(field["component_id"], str):
        raise Adapter_Error(f"{path}.component_id: must be a semantic component ID")
    if field["presence"] != "required":
        raise Adapter_Error(f"{path}.presence: initial Type IR lowering requires required fields")
    require_integer(field["tag"], f"{path}.tag", 1, schema_lock.MAX_FIELD_TAG)
    lowering = field["value"]
    if not isinstance(lowering, dict) or "kind" not in lowering:
        raise Adapter_Error(f"{path}.value: must be a closed scalar lowering")
    if lowering["kind"] == "boolean":
        require_object(lowering, f"{path}.value", {"kind"})
    elif lowering["kind"] in {"signed", "unsigned"}:
        require_object(lowering, f"{path}.value", {"kind", "maximum", "minimum"})
        for member in ("minimum", "maximum"):
            if (
                not isinstance(lowering[member], str)
                or schema_lock.DECIMAL.fullmatch(lowering[member]) is None
            ):
                raise Adapter_Error(f"{path}.value.{member}: must be a normalized decimal string")
        if int(lowering["minimum"]) > int(lowering["maximum"]):
            raise Adapter_Error(f"{path}.value: has an inverted range")
    else:
        raise Adapter_Error(f"{path}.value.kind: is unsupported by the initial Type IR adapter")
    return field


def lower_checked(
    checked: Any,
    overlay: dict[str, Any],
    consumer_lock: dict[str, Any],
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    if checked.profile not in {"strict", "fixture_shape"}:
        raise Adapter_Error("Type IR validation profile is not a wire-admissible profile")
    if checked.semantic_fingerprint != overlay["type_ir_semantic_fingerprint"]:
        raise Adapter_Error("$.type_ir_semantic_fingerprint: does not match the checked Type IR")
    document = checked.document
    if document.get("ir_version") != consumer_lock["ir_version"]:
        raise Adapter_Error("Type IR version differs from the consumer lock")
    if document.get("required_features") != consumer_lock["required_features"]:
        raise Adapter_Error("Type IR required features differ from the consumer lock")
    if document.get("optional_features") != [] or document.get("extensions") != {}:
        raise Adapter_Error("initial wire lowering rejects optional Type IR semantics")

    declarations = {item["stable_id"]: item for item in document["declarations"]}
    components = {item["stable_id"]: item for item in document["components"]}
    root_id = overlay["root_declaration_id"]
    root = declarations.get(root_id)
    if root is None:
        raise Adapter_Error("$.root_declaration_id: is absent from the checked Type IR")
    validate_safe_declaration(root, "$.type_ir.root")
    if root.get("declaration_form") != "type":
        raise Adapter_Error("$.type_ir.root.declaration_form: initial lowering requires a named type")
    if root.get("shape") != {"constraint": {"kind": "none"}, "kind": "record"}:
        raise Adapter_Error("$.type_ir.root.shape: initial lowering requires an unconstrained record")
    if root.get("references") != [] or root.get("related_view_ids") != []:
        raise Adapter_Error("$.type_ir.root: initial lowering rejects derived or alternate views")
    view_access = root.get("view_access")
    if not isinstance(view_access, dict):
        raise Adapter_Error("$.type_ir.root.view_access: is missing")
    known_boolean(
        view_access.get("consumer_can_name_components"),
        True,
        "$.type_ir.root.view_access.consumer_can_name_components",
    )
    if any(item.get("owner_id") == root_id for item in document["discriminants"]):
        raise Adapter_Error("$.type_ir.root: initial lowering rejects discriminants")

    root_components = sorted(
        (item for item in document["components"] if item.get("owner_id") == root_id),
        key=lambda item: item["declaration_order"],
    )
    overlay_fields = [
        validate_field_overlay(item, f"$.fields[{index}]")
        for index, item in enumerate(overlay["fields"])
    ]
    if [item["tag"] for item in overlay_fields] != sorted(item["tag"] for item in overlay_fields):
        raise Adapter_Error("$.fields: tags must be strictly increasing")
    if len({item["tag"] for item in overlay_fields}) != len(overlay_fields):
        raise Adapter_Error("$.fields: tags must be unique")
    mapped_ids = [item["component_id"] for item in overlay_fields]
    if len(set(mapped_ids)) != len(mapped_ids):
        raise Adapter_Error("$.fields: component IDs must be unique")
    if set(mapped_ids) != {item["stable_id"] for item in root_components}:
        raise Adapter_Error("$.fields: must map every root component exactly once")

    schema_fields: list[dict[str, Any]] = []
    binding_fields: list[dict[str, Any]] = []
    with_units = {declaration_unit(root, "$.type_ir.root")}
    for index, field in enumerate(overlay_fields):
        component = components[field["component_id"]]
        path = f"$.type_ir.component[{field['component_id']}]"
        if component.get("owner_id") != root_id or component.get("variant_path") != []:
            raise Adapter_Error(f"{path}: must be a direct unconditional root component")
        if component.get("default") != {"present": False}:
            raise Adapter_Error(f"{path}.default: initial lowering rejects defaults")
        known_boolean(component.get("aliased"), False, f"{path}.aliased")
        known_boolean(component.get("constant"), False, f"{path}.constant")
        type_reference = component.get("type")
        if not isinstance(type_reference, dict) or type_reference.get("constraint") != {"kind": "none"}:
            raise Adapter_Error(f"{path}.type: initial lowering rejects use-site constraints")
        type_declaration = declarations.get(type_reference.get("declaration_id"))
        if type_declaration is None:
            raise Adapter_Error(f"{path}.type: declaration is absent")
        lowering = field["value"]
        schema_field = {
            "presence": "required",
            "tag": field["tag"],
            "value": dict(lowering),
        }
        canonical_component = generate_ada.require_identifier(
            component.get("canonical_name"), f"{path}.canonical_name"
        )
        presentation_component = generate_ada.require_identifier(
            component.get("name"), f"{path}.name"
        )
        if presentation_component.casefold() != canonical_component:
            raise Adapter_Error(f"{path}.name: differs from the canonical component identity")
        binding_field: dict[str, Any] = {
            "ada_component": ada_identifier_from_canonical(
                component.get("canonical_name"), f"{path}.canonical_name"
            ),
            "tag": field["tag"],
        }
        if lowering["kind"] == "boolean":
            validate_boolean_type(type_declaration, f"{path}.type")
            binding_field["ada_scalar"] = "boolean"
        else:
            type_name = validate_integer_type(type_declaration, lowering, f"{path}.type")
            with_units.add(declaration_unit(type_declaration, f"{path}.type"))
            binding_field["ada_scalar"] = {"kind": "integer_type", "type_name": type_name}
        schema_fields.append(schema_field)
        binding_fields.append(binding_field)

    schema = {
        "family_id": overlay["family_id"],
        "fingerprint": "1" * 64,
        "lock_format": "flyology-wire-schema-lock",
        "lock_version": 1,
        "profile_id": overlay["profile_id"],
        "root": {
            "fields": schema_fields,
            "kind": "record",
            "reserved_tags": overlay["reserved_tags"],
        },
        "schema_revision": overlay["schema_revision"],
    }
    schema["fingerprint"] = schema_lock.schema_fingerprint(schema)
    schema_lock.validate_lock(schema)
    binding = {
        "binding_format": "flyology-wire-ada-binding",
        "binding_version": 1,
        "fields": binding_fields,
        "package_name": overlay["package_name"],
        "schema_fingerprint": schema["fingerprint"],
        "value_type": expanded_type_name(root, "$.type_ir.root"),
        "with_units": sorted(with_units, key=str.lower),
    }
    generate_ada.validate_binding(binding, schema)
    provenance = {
        "checker_sha256": consumer_lock["checker"]["sha256"],
        "consumer_format": "flyology-wire-type-ir-provenance",
        "consumer_version": 1,
        "overlay_sha256": sha256(canonical_bytes(overlay)),
        "type_ir_commit": consumer_lock["commit"],
        "type_ir_profile": checked.profile,
        "type_ir_schema_sha256": consumer_lock["schema"]["sha256"],
        "type_ir_semantic_fingerprint": checked.semantic_fingerprint,
        "type_ir_source_sha256": checked.source_sha256,
        "wire_schema_fingerprint": schema["fingerprint"],
    }
    return schema, binding, provenance


def render_json(value: Any) -> str:
    return json.dumps(value, ensure_ascii=True, indent=2, sort_keys=True) + "\n"


def write_or_check(path: Path, value: Any, check: bool) -> None:
    content = render_json(value)
    if check:
        try:
            existing = path.read_text(encoding="utf-8")
        except OSError as error:
            raise Adapter_Error(f"{path}: {error}") from error
        if existing != content:
            raise Adapter_Error(f"{path}: generated output is stale")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def validate_output_paths(
    outputs: list[Path], protected: list[Path], type_ir_root: Path
) -> None:
    resolved_outputs = [path.resolve() for path in outputs]
    if len(set(resolved_outputs)) != len(resolved_outputs):
        raise Adapter_Error("schema, binding, and provenance outputs must be distinct")
    resolved_protected = {path.resolve() for path in protected}
    if any(path in resolved_protected for path in resolved_outputs):
        raise Adapter_Error("an output path aliases an adapter input")
    resolved_root = type_ir_root.resolve()
    for path in resolved_outputs:
        try:
            path.relative_to(resolved_root)
        except ValueError:
            continue
        raise Adapter_Error("adapter outputs must not modify the reviewed Type IR checkout")


def adapt(
    type_ir_root: Path,
    type_ir_path: Path,
    overlay_path: Path,
    consumer_lock_path: Path,
    profile: str,
) -> tuple[dict[str, Any], dict[str, Any], dict[str, Any]]:
    consumer = load_consumer_lock(consumer_lock_path)
    with import_checker(type_ir_root, consumer) as checker:
        try:
            checked = checker.load_checked(type_ir_path, profile)
        except Exception as error:
            raise Adapter_Error(
                f"{type_ir_path}: Type IR {profile} validation failed: {error}"
            ) from error
    if profile == "fixture_shape":
        fixture = consumer["wire_fixture"]
        if checked.source_sha256 != fixture["source_sha256"]:
            raise Adapter_Error("test-only Type IR source differs from the reviewed wire fixture")
        if checked.semantic_fingerprint != fixture["semantic_fingerprint"]:
            raise Adapter_Error("test-only Type IR semantics differ from the reviewed wire fixture")
    overlay = load_overlay(overlay_path)
    return lower_checked(checked, overlay, consumer)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("type_ir_root", type=Path)
    parser.add_argument("type_ir", type=Path)
    parser.add_argument("overlay", type=Path)
    parser.add_argument("schema_output", type=Path)
    parser.add_argument("binding_output", type=Path)
    parser.add_argument("provenance_output", type=Path)
    parser.add_argument("--consumer-lock", type=Path, default=DEFAULT_CONSUMER_LOCK)
    parser.add_argument("--fixture-shape", action="store_true")
    parser.add_argument("--check", action="store_true")
    arguments = parser.parse_args()
    profile = "fixture_shape" if arguments.fixture_shape else "strict"
    try:
        validate_output_paths(
            [arguments.schema_output, arguments.binding_output, arguments.provenance_output],
            [arguments.type_ir, arguments.overlay, arguments.consumer_lock],
            arguments.type_ir_root,
        )
        schema, binding, provenance = adapt(
            arguments.type_ir_root,
            arguments.type_ir,
            arguments.overlay,
            arguments.consumer_lock,
            profile,
        )
        write_or_check(arguments.schema_output, schema, arguments.check)
        write_or_check(arguments.binding_output, binding, arguments.check)
        write_or_check(arguments.provenance_output, provenance, arguments.check)
    except (Adapter_Error, OSError, schema_lock.Lock_Error, generate_ada.Generator_Error) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
