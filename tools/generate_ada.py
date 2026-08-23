#!/usr/bin/env python3
"""Generate an initial statically bound Ada codec from a wire schema lock."""

from __future__ import annotations

import argparse
import re
import sys
from pathlib import Path
from typing import Any, Optional

import schema_lock
import schema_diff

BINDING_FORMAT = "flyology-wire-ada-binding"
ADA_IDENTIFIER = re.compile(r"[A-Za-z][A-Za-z0-9]*(?:_[A-Za-z0-9]+)*\Z")
ADA_RESERVED = {
    "abort", "abs", "abstract", "accept", "access", "aliased", "all", "and", "array",
    "at", "begin", "body", "case", "constant", "declare", "delay", "delta", "digits", "do",
    "else", "elsif", "end", "entry", "exception", "exit", "for", "function", "generic", "goto",
    "if", "in", "interface", "is", "limited", "loop", "mod", "new", "not", "null", "of", "or",
    "others", "out", "overriding", "package", "parallel", "pragma", "private", "procedure",
    "protected", "raise", "range", "record", "rem", "renames", "requeue", "return", "reverse",
    "select", "separate", "some", "subtype", "synchronized", "tagged", "task", "terminate", "then",
    "type", "until", "use", "when", "while", "with", "xor",
}
SCALAR_BINDINGS = {
    "boolean": "boolean",
    "signed": "interfaces_integer_64",
    "unsigned": "interfaces_unsigned_64",
}
ROOT_FIELD_PATH = re.compile(r"\$\.root\.field\[([1-9][0-9]*)\]\Z")


class Generator_Error(ValueError):
    """A closed Ada binding or generation failure."""


def require_identifier(value: Any, path: str) -> str:
    if not isinstance(value, str) or ADA_IDENTIFIER.fullmatch(value) is None:
        raise Generator_Error(f"{path}: must be an Ada identifier")
    if len(value) > 40:
        raise Generator_Error(f"{path}: exceeds the 40-character generator limit")
    if value.lower() in ADA_RESERVED:
        raise Generator_Error(f"{path}: must not be an Ada reserved word")
    return value


def require_expanded_name(value: Any, path: str) -> str:
    if not isinstance(value, str) or not value:
        raise Generator_Error(f"{path}: must be an expanded Ada name")
    for index, part in enumerate(value.split(".")):
        require_identifier(part, f"{path}[{index}]")
    if len(value) > 80:
        raise Generator_Error(f"{path}: exceeds the 80-character generator limit")
    return value


def validate_scalar_representation(
    value: Any, expected: str, path: str
) -> Optional[str]:
    if value == expected:
        return None
    if expected == "boolean" or not isinstance(value, dict) or set(value) != {
        "kind",
        "type_name",
    }:
        raise Generator_Error(f"{path}: must be {expected!r}")
    if value["kind"] != "integer_type":
        raise Generator_Error(f"{path}.kind: must be 'integer_type'")
    return require_expanded_name(value["type_name"], f"{path}.type_name")


def validate_binding(binding: Any, schema: dict[str, Any]) -> list[dict[str, Any]]:
    keys = {
        "binding_format",
        "binding_version",
        "fields",
        "package_name",
        "schema_fingerprint",
        "value_type",
        "with_units",
    }
    if not isinstance(binding, dict) or set(binding) != keys:
        raise Generator_Error("$: Ada binding has incorrect closed keys")
    if (
        binding["binding_format"] != BINDING_FORMAT
        or type(binding["binding_version"]) is not int
        or binding["binding_version"] != 1
    ):
        raise Generator_Error("$: Ada binding format or version is unsupported")
    if binding["schema_fingerprint"] != schema["fingerprint"]:
        raise Generator_Error("$.schema_fingerprint: does not match the schema lock")
    require_expanded_name(binding["package_name"], "$.package_name")
    value_type = require_expanded_name(binding["value_type"], "$.value_type")
    units = binding["with_units"]
    if not isinstance(units, list) or not units:
        raise Generator_Error("$.with_units: must be a nonempty array")
    normalized_units = [
        require_expanded_name(unit, f"$.with_units[{index}]") for index, unit in enumerate(units)
    ]
    if normalized_units != sorted(normalized_units, key=str.lower):
        raise Generator_Error("$.with_units: must be in Ada-insensitive lexical order")
    if len({unit.lower() for unit in normalized_units}) != len(normalized_units):
        raise Generator_Error("$.with_units: must not contain duplicates")
    if value_type.rsplit(".", 1)[0].lower() not in {unit.lower() for unit in normalized_units}:
        raise Generator_Error("$.with_units: must include the value type's declaring unit")

    root = schema["root"]
    if root["kind"] != "record":
        raise Generator_Error("$.root: the initial Ada backend requires a record")
    schema_fields = {field["tag"]: field for field in root["fields"]}
    if not schema_fields:
        raise Generator_Error("$.root: the initial Ada backend requires a nonempty record")
    fields = binding["fields"]
    if not isinstance(fields, list):
        raise Generator_Error("$.fields: must be an array")
    if len(fields) != len(schema_fields):
        raise Generator_Error("$.fields: must bind every schema field exactly once")
    result: list[dict[str, Any]] = []
    seen_components: set[str] = set()
    previous_tag = 0
    for index, field_binding in enumerate(fields):
        path = f"$.fields[{index}]"
        if not isinstance(field_binding, dict) or "tag" not in field_binding:
            raise Generator_Error(f"{path}: has incorrect closed keys")
        tag = field_binding["tag"]
        if isinstance(tag, bool) or not isinstance(tag, int) or tag <= previous_tag:
            raise Generator_Error(f"{path}.tag: must be a strictly increasing integer")
        previous_tag = tag
        if tag not in schema_fields:
            raise Generator_Error(f"{path}.tag: is absent from the schema lock")
        schema_field = schema_fields[tag]
        presence = schema_field["presence"]
        if presence not in {"required", "defaulted", "optional"}:
            raise Generator_Error(
                f"{path}: the initial Ada backend has an unsupported field presence"
            )
        kind = schema_field["value"]["kind"]
        expected_scalar = SCALAR_BINDINGS.get(kind)
        if expected_scalar is not None:
            field_keys = {"ada_component", "ada_scalar", "tag"}
            if presence == "optional":
                field_keys.add("ada_present_component")
            if set(field_binding) != field_keys:
                raise Generator_Error(f"{path}: has incorrect closed scalar keys")
            conversion_type = validate_scalar_representation(
                field_binding["ada_scalar"], expected_scalar, f"{path}.ada_scalar"
            )
            component = require_identifier(field_binding["ada_component"], f"{path}.ada_component")
            if component.lower() in seen_components:
                raise Generator_Error(f"{path}.ada_component: duplicates another component")
            seen_components.add(component.lower())
            present_component = None
            if presence == "optional":
                present_component = require_identifier(
                    field_binding["ada_present_component"], f"{path}.ada_present_component"
                )
                if present_component.lower() in seen_components:
                    raise Generator_Error(
                        f"{path}.ada_present_component: duplicates another component"
                    )
                seen_components.add(present_component.lower())
            default = None
            if presence == "defaulted":
                default = scalar_default_literal(
                    schema_field["value"], schema_field["default_wire"], f"{path}.default_wire"
                )
            result.append(
                {
                    "component": component,
                    "default": default,
                    "kind": "scalar",
                    "presence": presence,
                    "present_component": present_component,
                    "schema": schema_field,
                    "scalar": expected_scalar,
                    "conversion_type": conversion_type,
                }
            )
            continue
        if kind == "enumeration":
            field_keys = {"ada_component", "ada_literals", "tag"}
            if set(field_binding) != field_keys:
                raise Generator_Error(f"{path}: has incorrect closed enumeration keys")
            if presence != "required":
                raise Generator_Error(
                    f"{path}: non-required enumerations are not yet supported"
                )
            component = require_identifier(
                field_binding["ada_component"], f"{path}.ada_component"
            )
            if component.lower() in seen_components:
                raise Generator_Error(f"{path}.ada_component: duplicates another component")
            seen_components.add(component.lower())
            literal_bindings = field_binding["ada_literals"]
            schema_tags = [value["tag"] for value in schema_field["value"]["values"]]
            if not isinstance(literal_bindings, list) or len(literal_bindings) != len(schema_tags):
                raise Generator_Error(
                    f"{path}.ada_literals: must bind every schema enumeration value"
                )
            literals: list[dict[str, Any]] = []
            seen_literals: set[str] = set()
            for literal_index, literal_binding in enumerate(literal_bindings):
                literal_path = f"{path}.ada_literals[{literal_index}]"
                if not isinstance(literal_binding, dict) or set(literal_binding) != {
                    "ada_literal",
                    "tag",
                }:
                    raise Generator_Error(
                        f"{literal_path}: has incorrect closed literal keys"
                    )
                if literal_binding["tag"] != schema_tags[literal_index]:
                    raise Generator_Error(
                        f"{literal_path}.tag: must match the schema value in tag order"
                    )
                literal = require_expanded_name(
                    literal_binding["ada_literal"], f"{literal_path}.ada_literal"
                )
                if literal.lower() in seen_literals:
                    raise Generator_Error(
                        f"{literal_path}.ada_literal: duplicates another literal"
                    )
                seen_literals.add(literal.lower())
                literals.append(
                    {
                        "literal": literal,
                        "name": literal.rsplit(".", 1)[-1],
                        "tag": literal_binding["tag"],
                    }
                )
            result.append(
                {
                    "component": component,
                    "default": None,
                    "kind": "enumeration",
                    "literals": literals,
                    "presence": presence,
                    "present_component": None,
                    "schema": schema_field,
                }
            )
            continue
        if kind == "variant":
            field_keys = {"ada_alternatives", "ada_component", "tag"}
            if set(field_binding) != field_keys:
                raise Generator_Error(f"{path}: has incorrect closed variant keys")
            if presence != "required":
                raise Generator_Error(f"{path}: non-required variants are not yet supported")
            if len(schema_fields) != 1:
                raise Generator_Error(
                    f"{path}: the initial variant backend requires the only root field"
                )
            component = require_identifier(
                field_binding["ada_component"], f"{path}.ada_component"
            )
            if component.lower() in seen_components:
                raise Generator_Error(f"{path}.ada_component: duplicates another component")
            seen_components.add(component.lower())
            alternative_bindings = field_binding["ada_alternatives"]
            schema_alternatives = schema_field["value"]["alternatives"]
            if not isinstance(alternative_bindings, list) or len(alternative_bindings) != len(
                schema_alternatives
            ):
                raise Generator_Error(
                    f"{path}.ada_alternatives: must bind every schema variant alternative"
                )
            alternatives: list[dict[str, Any]] = []
            seen_literals: set[str] = set()
            for alternative_index, (alternative_binding, schema_alternative) in enumerate(
                zip(alternative_bindings, schema_alternatives)
            ):
                alternative_path = f"{path}.ada_alternatives[{alternative_index}]"
                if not isinstance(alternative_binding, dict) or set(alternative_binding) != {
                    "ada_literal",
                    "fields",
                    "tag",
                }:
                    raise Generator_Error(
                        f"{alternative_path}: has incorrect closed alternative keys"
                    )
                if alternative_binding["tag"] != schema_alternative["tag"]:
                    raise Generator_Error(
                        f"{alternative_path}.tag: must match the schema alternative in tag order"
                    )
                literal = require_expanded_name(
                    alternative_binding["ada_literal"],
                    f"{alternative_path}.ada_literal",
                )
                if literal.lower() in seen_literals:
                    raise Generator_Error(
                        f"{alternative_path}.ada_literal: duplicates another selector literal"
                    )
                seen_literals.add(literal.lower())
                schema_members = schema_alternative["value"]["fields"]
                member_bindings = alternative_binding["fields"]
                if not isinstance(member_bindings, list) or len(member_bindings) != len(
                    schema_members
                ):
                    raise Generator_Error(
                        f"{alternative_path}.fields: must bind every alternative field"
                    )
                members: list[dict[str, Any]] = []
                for member_index, (member_binding, schema_member) in enumerate(
                    zip(member_bindings, schema_members)
                ):
                    member_path = f"{alternative_path}.fields[{member_index}]"
                    if not isinstance(member_binding, dict) or set(member_binding) != {
                        "ada_component",
                        "ada_scalar",
                        "tag",
                    }:
                        raise Generator_Error(
                            f"{member_path}: has incorrect closed scalar keys"
                        )
                    if member_binding["tag"] != schema_member["tag"]:
                        raise Generator_Error(
                            f"{member_path}.tag: must match the schema field in tag order"
                        )
                    if schema_member["presence"] != "required":
                        raise Generator_Error(
                            f"{member_path}: the initial variant backend requires required fields"
                        )
                    scalar = SCALAR_BINDINGS.get(schema_member["value"]["kind"])
                    if scalar is None:
                        raise Generator_Error(
                            f"{member_path}: the initial variant field kind is unsupported"
                        )
                    if member_binding["ada_scalar"] != scalar:
                        raise Generator_Error(
                            f"{member_path}.ada_scalar: must be {scalar!r}"
                        )
                    member_component = require_identifier(
                        member_binding["ada_component"],
                        f"{member_path}.ada_component",
                    )
                    if member_component.lower() in seen_components:
                        raise Generator_Error(
                            f"{member_path}.ada_component: duplicates another component"
                        )
                    seen_components.add(member_component.lower())
                    symbol = f"{component}_{literal.rsplit('.', 1)[-1]}_{member_component}"
                    if len(symbol) > 72:
                        raise Generator_Error(
                            f"{member_path}: generated variant symbol exceeds 72 characters"
                        )
                    members.append(
                        {
                            "component": member_component,
                            "scalar": scalar,
                            "schema": schema_member,
                            "symbol": symbol,
                        }
                    )
                alternatives.append(
                    {
                        "fields": members,
                        "literal": literal,
                        "name": literal.rsplit(".", 1)[-1],
                        "schema": schema_alternative,
                        "tag": schema_alternative["tag"],
                    }
                )
            result.append(
                {
                    "alternatives": alternatives,
                    "component": component,
                    "default": None,
                    "kind": "variant",
                    "presence": presence,
                    "present_component": None,
                    "schema": schema_field,
                }
            )
            continue
        if kind in {"bytes", "text"}:
            mode_key = "ada_bytes" if kind == "bytes" else "ada_text"
            expected_mode = (
                "stream_element_array" if kind == "bytes" else "utf_8_stream_element_array"
            )
            field_keys = {
                mode_key,
                "ada_component",
                "ada_length_component",
                "borrowed_observer",
                "tag",
            }
            if set(field_binding) != field_keys:
                raise Generator_Error(f"{path}: has incorrect closed {kind} keys")
            if presence != "required":
                raise Generator_Error(f"{path}: non-required {kind} is not yet supported")
            if field_binding[mode_key] != expected_mode:
                raise Generator_Error(f"{path}.{mode_key}: must be {expected_mode!r}")
            if type(field_binding["borrowed_observer"]) is not bool:
                raise Generator_Error(f"{path}.borrowed_observer: must be Boolean")
            component = require_identifier(field_binding["ada_component"], f"{path}.ada_component")
            length_component = require_identifier(
                field_binding["ada_length_component"], f"{path}.ada_length_component"
            )
            if len(component) > 24 or len(length_component) > 24:
                raise Generator_Error(f"{path}: octet component names exceed the 24-character limit")
            for member, member_path in (
                (component, f"{path}.ada_component"),
                (length_component, f"{path}.ada_length_component"),
            ):
                if member.lower() in seen_components:
                    raise Generator_Error(f"{member_path}: duplicates another component")
                seen_components.add(member.lower())
            result.append(
                {
                    "borrowed_observer": field_binding["borrowed_observer"],
                    "component": component,
                    "default": None,
                    "kind": kind,
                    "length_component": length_component,
                    "presence": presence,
                    "present_component": None,
                    "schema": schema_field,
                }
            )
            continue
        if kind != "sequence":
            raise Generator_Error(f"{path}: the initial Ada backend does not support {kind!r}")
        field_keys = {
            "ada_component",
            "ada_element_scalar",
            "ada_length_component",
            "tag",
        }
        if set(field_binding) != field_keys:
            raise Generator_Error(f"{path}: has incorrect closed sequence keys")
        if presence != "required":
            raise Generator_Error(f"{path}: non-required sequences are not yet supported")
        sequence = schema_field["value"]
        if len(sequence["dimensions"]) != 1:
            raise Generator_Error(f"{path}: the initial sequence backend requires rank one")
        element_scalar = SCALAR_BINDINGS.get(sequence["element"]["kind"])
        if element_scalar is None:
            raise Generator_Error(f"{path}: sequence element kind is unsupported")
        if field_binding["ada_element_scalar"] != element_scalar:
            raise Generator_Error(f"{path}.ada_element_scalar: must be {element_scalar!r}")
        component = require_identifier(field_binding["ada_component"], f"{path}.ada_component")
        length_component = require_identifier(
            field_binding["ada_length_component"], f"{path}.ada_length_component"
        )
        if len(component) > 24 or len(length_component) > 24:
            raise Generator_Error(f"{path}: sequence component names exceed the 24-character limit")
        for member, member_path in (
            (component, f"{path}.ada_component"),
            (length_component, f"{path}.ada_length_component"),
        ):
            if member.lower() in seen_components:
                raise Generator_Error(f"{member_path}: duplicates another component")
            seen_components.add(member.lower())
        result.append(
            {
                "component": component,
                "default": None,
                "element_scalar": element_scalar,
                "kind": "sequence",
                "length_component": length_component,
                "presence": presence,
                "present_component": None,
                "schema": schema_field,
            }
        )
    if set(schema_fields) != {field["schema"]["tag"] for field in result}:
        raise Generator_Error("$.fields: must bind every schema field exactly once")
    if any(
        field["kind"] in {"bytes", "text"} and field["borrowed_observer"]
        for field in result
    ):
        if any(field["presence"] != "required" for field in result):
            raise Generator_Error(
                "$.fields: the initial borrowed observer requires all fields to be required"
            )
        if any(field["kind"] not in {"scalar", "bytes", "text"} for field in result):
            raise Generator_Error(
                "$.fields: the initial borrowed observer supports only scalar and byte fields"
            )
        if any(
            field["kind"] in {"bytes", "text"} and not field["borrowed_observer"]
            for field in result
        ):
            raise Generator_Error(
                "$.fields: every byte field must opt into the generated borrowed observer"
            )
        if any(
            field["kind"] == "scalar" and field["conversion_type"] is not None
            for field in result
        ):
            raise Generator_Error(
                "$.fields: the initial borrowed observer requires exact scalar representations"
            )
    return result


def borrowed_observer_enabled(fields: list[dict[str, Any]]) -> bool:
    return any(
        field["kind"] in {"bytes", "text"} and field["borrowed_observer"]
        for field in fields
    )


def observer_value_type(field: dict[str, Any]) -> str:
    if field["kind"] in {"bytes", "text"}:
        return "Flyology_Wire.Octet_Array"
    return {
        "boolean": "Boolean",
        "signed": "Interfaces.Integer_64",
        "unsigned": "Interfaces.Unsigned_64",
    }[field["schema"]["value"]["kind"]]


def observer_uses_interfaces(fields: list[dict[str, Any]]) -> bool:
    return borrowed_observer_enabled(fields) and any(
        field["kind"] == "scalar"
        and field["schema"]["value"]["kind"] in {"signed", "unsigned"}
        for field in fields
    )


def scalar_default_literal(value: dict[str, Any], encoded: str, path: str) -> str:
    data = bytes.fromhex(encoded)
    kind = value["kind"]
    if kind == "boolean":
        return "True" if data == b"\x01" else "False"
    if kind not in {"signed", "unsigned"}:
        raise Generator_Error(f"{path}: the initial backend cannot construct {kind!r}")
    raw, position = schema_lock.read_varint(data, 0, len(data), path)
    if position != len(data):
        raise Generator_Error(f"{path}: scalar default has trailing octets")
    if kind == "signed":
        raw = raw // 2 if raw % 2 == 0 else -(raw // 2) - 1
    return ada_integer(str(raw))


def validate_compatible_writers(
    reader: dict[str, Any],
    fields: list[dict[str, Any]],
    pairs: list[tuple[Path, Path]],
) -> list[dict[str, Any]]:
    local_fields = {field["schema"]["tag"]: field for field in fields}
    result: list[dict[str, Any]] = []
    fingerprints: set[str] = set()
    for writer_path, approval_path in pairs:
        writer = schema_lock.validate_lock(schema_lock.load(writer_path))
        report = schema_diff.directional_diff(writer, reader)
        approval = schema_lock.load(approval_path)
        schema_diff.validate_approval(report, reader, approval)
        fingerprint = writer["fingerprint"]
        if fingerprint == reader["fingerprint"] or fingerprint in fingerprints:
            raise Generator_Error(f"{writer_path}: compatible writer must be unique and nonlocal")
        fingerprints.add(fingerprint)
        construct: dict[int, str] = {}
        ignored: dict[int, dict[str, Any]] = {}
        for resolution in approval["resolutions"]:
            match = ROOT_FIELD_PATH.fullmatch(resolution["path"])
            if match is None:
                raise Generator_Error(
                    f"{resolution['path']}: the initial backend supports only root record fields"
                )
            tag = int(match.group(1))
            if resolution["action"] == "construct_reader_field":
                if tag not in local_fields:
                    raise Generator_Error(f"{resolution['path']}: has no bound local field")
                construct[tag] = scalar_default_literal(
                    local_fields[tag]["schema"]["value"],
                    resolution["default_wire"],
                    resolution["path"],
                )
            elif resolution["action"] == "ignore_writer_field":
                writer_fields = {item["tag"]: item for item in writer["root"]["fields"]}
                ignored_field = writer_fields[tag]
                ignored_value = ignored_field["value"]
                if ignored_value["kind"] != "bytes":
                    raise Generator_Error(
                        f"{resolution['path']}: the initial backend can ignore only bounded bytes"
                    )
                if ignored_field["presence"] == "defaulted":
                    raise Generator_Error(
                        f"{resolution['path']}: defaulted ignored fields are not yet supported"
                    )
                ignored[tag] = ignored_value
            else:
                raise Generator_Error(f"{resolution['path']}: unsupported compatibility action")
        result.append(
            {
                "construct": construct,
                "ignored": ignored,
                "schema": writer,
            }
        )
    return sorted(
        result,
        key=lambda entry: (entry["schema"]["schema_revision"], entry["schema"]["fingerprint"]),
    )


def ada_integer(text: str) -> str:
    negative = text.startswith("-")
    digits = text[1:] if negative else text
    first = len(digits) % 3 or 3
    groups = [digits[:first]]
    groups.extend(digits[index : index + 3] for index in range(first, len(digits), 3))
    return ("-" if negative else "") + "_".join(groups)


def append_octets(lines: list[str], value: str, indent: int) -> None:
    octets = [value[index : index + 2].upper() for index in range(0, len(value), 2)]
    prefix = " " * indent
    continuation = " " * (indent + 2)
    for index, octet in enumerate(octets):
        lead = "([" if index == 0 else ""
        tail = "])" if index == len(octets) - 1 else ","
        lines.append(f"{prefix if index == 0 else continuation}{lead}16#{octet}#{tail}")


def failure_value(
    fields: list[dict[str, Any]], overrides: Optional[dict[str, str]] = None
) -> str:
    overrides = overrides or {}
    values: list[str] = []
    for field in fields:
        component = field["component"]
        if field["kind"] == "scalar":
            value = overrides.get(component, scalar_initial_value(field["schema"]["value"]))
            values.append(f"{component} => {value}")
            if field["present_component"] is not None:
                present = field["present_component"]
                values.append(f"{present} => {overrides.get(present, 'False')}")
            continue
        if field["kind"] == "enumeration":
            value = overrides.get(component, field["literals"][0]["literal"])
            values.append(f"{component} => {value}")
            continue
        if field["kind"] in {"bytes", "text"}:
            values.append(f"{component} => {overrides.get(component, '[others => 0]')}")
            length_component = field["length_component"]
            length = ada_integer(field["schema"]["value"]["minimum_octets"])
            values.append(f"{length_component} => {overrides.get(length_component, length)}")
            continue
        element = scalar_initial_value(field["schema"]["value"]["element"])
        values.append(f"{component} => {overrides.get(component, f'[others => {element}]')}")
        length_component = field["length_component"]
        length = ada_integer(field["schema"]["value"]["dimensions"][0]["minimum_count"])
        values.append(f"{length_component} => {overrides.get(length_component, length)}")
    return "(" + ", ".join(values) + ")"


def scalar_initial_value(value: dict[str, Any]) -> str:
    if value["kind"] == "boolean":
        return "False"
    return ada_integer(value["minimum"])


def append_value(
    lines: list[str],
    prefix: str,
    fields: list[dict[str, Any]],
    indent: int,
    overrides: Optional[dict[str, str]] = None,
) -> None:
    value = failure_value(fields, overrides)
    if len(prefix) + 1 + len(value) + 1 <= 110:
        lines.append(f"{prefix} {value};")
        return
    associations = value[1:-1].split(", ")
    lines.append(prefix)
    for index, association in enumerate(associations):
        lead = "(" if index == 0 else " "
        tail = ");" if index == len(associations) - 1 else ","
        lines.append(" " * indent + lead + association + tail)


def append_condition(lines: list[str], conditions: list[str], indent: int) -> None:
    prefix = " " * indent
    joined = " or else ".join(conditions)
    if indent + len("if ") + len(joined) + len(" then") <= 110:
        lines.append(f"{prefix}if {joined} then")
        return
    lines.append(f"{prefix}if {conditions[0]}")
    lines.extend(f"{prefix}  or else {condition}" for condition in conditions[1:])
    lines.append(f"{prefix}then")


def append_schema_identity(
    lines: list[str], name: str, schema: dict[str, Any], use_local_family: bool = False
) -> None:
    lines.extend(
        [
            f"   {name} : constant Flyology_Wire.Codecs.Schema_Identity :=",
            "     (Family      =>"
            + (" Local_Schema.Family," if use_local_family else ""),
        ]
    )
    if not use_local_family:
        lines.append("        Flyology_Wire.Identities.Family_From_Bytes")
        append_octets(lines, schema["family_id"], 10)
        lines[-1] += ","
    lines.extend(
        [
            "      Fingerprint =>",
            "        Flyology_Wire.Identities.Fingerprint_From_Bytes",
        ]
    )
    append_octets(lines, schema["fingerprint"], 10)
    lines[-1] += ","
    lines.extend(
        [
            f"      Revision    => {schema['schema_revision']},",
            "      Profile     =>"
            + (
                " Local_Schema.Profile);"
                if use_local_family
                else " Flyology_Wire.Profiles.Canonical_Tagged);"
            ),
        ]
    )


def variant_associations(
    field: dict[str, Any], overrides: Optional[dict[str, str]] = None
) -> list[str]:
    overrides = overrides or {}
    component = field["component"]
    result = [
        f"{component} => {overrides.get(component, field['alternatives'][0]['literal'])}"
    ]
    for alternative in field["alternatives"]:
        for member in alternative["fields"]:
            member_component = member["component"]
            initial = scalar_initial_value(member["schema"]["value"])
            result.append(
                f"{member_component} => {overrides.get(member_component, initial)}"
            )
    return result


def append_variant_value(
    lines: list[str],
    prefix: str,
    field: dict[str, Any],
    indent: int,
    overrides: Optional[dict[str, str]] = None,
) -> None:
    associations = variant_associations(field, overrides)
    value = "(" + ", ".join(associations) + ")"
    if len(prefix) + 1 + len(value) + 1 <= 110:
        lines.append(f"{prefix} {value};")
        return
    lines.append(prefix)
    for index, association in enumerate(associations):
        lead = "(" if index == 0 else " "
        tail = ");" if index == len(associations) - 1 else ","
        lines.append(" " * indent + lead + association + tail)


def render_spec(
    schema: dict[str, Any],
    binding: dict[str, Any],
    fields: list[dict[str, Any]],
    compatible: Optional[list[dict[str, Any]]] = None,
) -> str:
    compatible = compatible or []
    observer = borrowed_observer_enabled(fields)
    lines: list[str] = []
    units_by_key = {
        unit.lower(): unit
        for unit in (
            "Flyology_Wire.Codecs.Contracts",
            "Flyology_Wire.Identities",
            "Flyology_Wire.Profiles",
            *(("Interfaces",) if observer_uses_interfaces(fields) else ()),
            *binding["with_units"],
        )
    }
    units = sorted(units_by_key.values(), key=str.lower)
    lines.extend(f"with {unit};" for unit in units)
    lines.extend(
        ["", f"package {binding['package_name']} is", f"   subtype Value is {binding['value_type']};", ""]
    )
    append_schema_identity(lines, "Local_Schema", schema)
    for index, entry in enumerate(compatible, 1):
        lines.append("")
        append_schema_identity(lines, f"Accepted_Writer_{index}_Schema", entry["schema"], True)
        lines.extend(
            [
                f"   Accepted_Writer_{index}_Maximum_Encoded_Size : constant Flyology_Wire.Byte_Count :=",
                f"     {schema_lock.maximum_size(entry['schema']['root'])};",
            ]
        )
    lines.extend(
        [
            "",
            "   Value_Descriptor : constant Flyology_Wire.Codecs.Codec_Descriptor :=",
            "     (Schema => Local_Schema,",
            "      Maximum_Encoded_Size =>",
            f"        Flyology_Wire.Codecs.Bounded ({schema_lock.maximum_size(schema['root'])}));",
            "",
            "   procedure Measure",
            "     (Item   : Value;",
            "      Size   : out Flyology_Wire.Byte_Count;",
            "      Status : out Flyology_Wire.Codecs.Measure_Status);",
            "",
            "   procedure Encode",
            "     (Item    : Value;",
            "      Output  : in out Flyology_Wire.Octet_Array;",
            "      Written : out Flyology_Wire.Octet_Count;",
            "      Status  : out Flyology_Wire.Codecs.Encode_Status);",
            "",
            "   procedure Decode",
            "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
            "      Input  : Flyology_Wire.Octet_Array;",
            "      Item   : out Value;",
            "      Status : out Flyology_Wire.Codecs.Decode_Status);",
        ]
    )
    if observer:
        lines.extend(["", "   generic"])
        for field in fields:
            lines.append(
                f"      with procedure Visit_{field['component']} "
                f"(Value : {observer_value_type(field)});"
            )
        lines.extend(
            [
                "   procedure Validate_And_Visit",
                "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
                "      Input  : Flyology_Wire.Octet_Array;",
                "      Status : out Flyology_Wire.Codecs.Decode_Status);",
            ]
        )
    lines.extend(
        [
            "",
            "   package Contract is new",
            "     Flyology_Wire.Codecs.Contracts",
            "       (Value_Type       => Value,",
            "        Value_Descriptor => Value_Descriptor,",
            "        Measure_Value    => Measure,",
            "        Encode_Value     => Encode,",
            "        Decode_Value     => Decode);",
            f"end {binding['package_name']};",
        ]
    )
    return "\n".join(lines) + "\n"


def size_expression(field: dict[str, Any]) -> str:
    return scalar_size_expression(
        field["schema"]["value"], scalar_wire_expression(field, f"Item.{field['component']}")
    )


def size_argument_lines(field: dict[str, Any], indent: str) -> list[str]:
    expression = size_expression(field)
    if field.get("conversion_type") is None:
        return [f"{indent}{expression},"]
    prefix = "Flyology_Wire.Byte_Count ("
    if not expression.startswith(prefix) or not expression.endswith(")"):
        raise Generator_Error("internal error: converted scalar size expression is malformed")
    return [
        f"{indent}Flyology_Wire.Byte_Count",
        f"{indent}  ({expression[len(prefix) : -1]}),",
    ]


def scalar_wire_expression(field: dict[str, Any], expression: str) -> str:
    conversion_type = field.get("conversion_type")
    if conversion_type is None:
        return expression
    target = (
        "Interfaces.Unsigned_64"
        if field["schema"]["value"]["kind"] == "unsigned"
        else "Interfaces.Integer_64"
    )
    return f"{target} ({expression})"


def interface_scalar_bounds(kind: str) -> tuple[tuple[str, str], tuple[str, str]]:
    type_name = "Interfaces.Unsigned_64" if kind == "unsigned" else "Interfaces.Integer_64"
    return (("First", f"{type_name}'First"), ("Last", f"{type_name}'Last"))


def scalar_size_expression(value: dict[str, Any], expression: str) -> str:
    kind = value["kind"]
    if kind == "boolean":
        return "1"
    if kind == "unsigned":
        return f"Flyology_Wire.Byte_Count (Profile.Unsigned_Size ({expression}))"
    return (
        "Flyology_Wire.Byte_Count "
        f"(Profile.Unsigned_Size (Profile.ZigZag_Encode ({expression})))"
    )


def include_expression(field: dict[str, Any]) -> Optional[str]:
    if field["present_component"] is not None:
        return f"Item.{field['present_component']}"
    if field["default"] is None:
        return None
    return f"Item.{field['component']} /= {field['default']}"


def invalid_expression(field: dict[str, Any], expression: str) -> Optional[str]:
    return scalar_invalid_expression(field["schema"]["value"], expression)


def scalar_invalid_expression(value: dict[str, Any], expression: str) -> Optional[str]:
    if value["kind"] == "boolean":
        return None
    minimum = int(value["minimum"])
    maximum = int(value["maximum"])
    type_minimum = 0 if value["kind"] == "unsigned" else schema_lock.I64_MIN
    type_maximum = schema_lock.U64_MAX if value["kind"] == "unsigned" else schema_lock.I64_MAX
    conditions: list[str] = []
    if minimum > type_minimum:
        conditions.append(f"{expression} < {ada_integer(value['minimum'])}")
    if maximum < type_maximum:
        conditions.append(f"{expression} > {ada_integer(value['maximum'])}")
    return " or else ".join(conditions) or None


def write_call(field: dict[str, Any]) -> str:
    return scalar_write_call(
        field["schema"]["value"],
        scalar_wire_expression(field, f"Item.{field['component']}"),
        "Nested",
    )


def scalar_write_call(value: dict[str, Any], expression: str, cursor: str) -> str:
    kind = value["kind"]
    suffix = {"boolean": "Boolean", "signed": "Signed", "unsigned": "Unsigned"}[kind]
    return f"Profile.Write_{suffix} (Output, {cursor}, {expression}, Write_Result);"


def read_call(field: dict[str, Any], target: str) -> str:
    return scalar_read_call(field["schema"]["value"], target, "Nested")


def scalar_read_call(value: dict[str, Any], target: str, cursor: str) -> str:
    kind = value["kind"]
    suffix = {"boolean": "Boolean", "signed": "Signed", "unsigned": "Unsigned"}[kind]
    return f"Profile.Read_{suffix} (Input, {cursor}, {target}, Read_Result);"


def bound_scalars(fields: list[dict[str, Any]]) -> set[str]:
    result: set[str] = set()
    for field in fields:
        if field["kind"] == "scalar":
            result.add(field["scalar"])
        elif field["kind"] == "enumeration":
            result.add("interfaces_unsigned_64")
        elif field["kind"] in {"bytes", "text"}:
            result.add("interfaces_unsigned_64")
        else:
            result.update({"interfaces_unsigned_64", field["element_scalar"]})
    return result


def append_borrowed_observer_body(
    lines: list[str], fields: list[dict[str, Any]]
) -> None:
    has_scalar = any(field["kind"] == "scalar" for field in fields)
    lines.extend(
        [
            "",
            "   procedure Validate_For_Visit",
            "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
            "      Input  : Flyology_Wire.Octet_Array;",
            "      Status : out Flyology_Wire.Codecs.Decode_Status)",
            "   is",
            "      Reader        : Profile.Read_Cursor;",
            *(["      Nested        : Profile.Read_Cursor;"] if has_scalar else []),
            "      Previous      : Profile.Tag_Number := Profile.No_Tag;",
            "      Tag           : Profile.Field_Tag;",
            "      Region        : Profile.Extent;",
            *(["      Cursor_Result : Profile.Cursor_Status;"] if has_scalar else []),
            "      Read_Result   : Profile.Read_Status;",
        ]
    )
    for field in fields:
        component = field["component"]
        if field["kind"] == "scalar":
            lines.append(
                f"      Observed_{component} : {observer_value_type(field)};"
            )
        elif field["kind"] == "text":
            lines.extend(
                [
                    f"      Observed_{component}_Scalar_Count : Flyology_Wire.Octet_Count;",
                    f"      Observed_{component}_UTF_8_Status : Profile.UTF_8_Status;",
                ]
            )
        lines.append(f"      Seen_{component} : Boolean := False;")
    lines.extend(
        [
            "   begin",
            "      if Writer /= Local_Schema then",
            "         Status := Flyology_Wire.Codecs.Incompatible;",
            "         return;",
            "      end if;",
            "",
            "      Profile.Initialize (Reader, Input);",
            "      while not Profile.At_End (Reader) loop",
            "         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);",
            "         if Read_Result /= Profile.Read then",
            "            Status := Map_Read_Error (Read_Result);",
            "            return;",
            "         end if;",
            "",
        ]
    )
    for index, field in enumerate(fields):
        component = field["component"]
        keyword = "if" if index == 0 else "elsif"
        lines.append(f"         {keyword} Tag = {component}_Tag then")
        if field["kind"] == "scalar":
            lines.extend(
                [
                    "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                    "            "
                    + scalar_read_call(
                        field["schema"]["value"], f"Observed_{component}", "Nested"
                    ),
                    "            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then",
                    "               Status := Map_Read_Error (Read_Result);",
                    "               return;",
                    "            end if;",
                ]
            )
            invalid = invalid_expression(field, f"Observed_{component}")
            if invalid is not None:
                lines.extend(
                    [
                        f"            if {invalid} then",
                        "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "               return;",
                        "            end if;",
                    ]
                )
        else:
            value = field["schema"]["value"]
            conditions = []
            if int(value["minimum_octets"]) > 0:
                conditions.append(
                    f"Flyology_Wire.Byte_Count (Region.Length) < {ada_integer(value['minimum_octets'])}"
                )
            if int(value["maximum_octets"]) < schema_lock.U64_MAX:
                conditions.append(
                    f"Flyology_Wire.Byte_Count (Region.Length) > {ada_integer(value['maximum_octets'])}"
                )
            if conditions:
                append_condition(lines, conditions, 12)
                lines.extend(
                    [
                        "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "               return;",
                        "            end if;",
                    ]
                )
            if field["kind"] == "text":
                lines.extend(
                    [
                        "            Profile.Validate_UTF_8",
                        f"              (Input, Region, Observed_{component}_Scalar_Count,",
                        f"               Observed_{component}_UTF_8_Status);",
                    ]
                )
                scalar_conditions = [
                    f"Observed_{component}_UTF_8_Status /= Profile.Valid_UTF_8"
                ]
                if int(value["minimum_scalars"]) > 0:
                    scalar_conditions.append(
                        f"Observed_{component}_Scalar_Count < {ada_integer(value['minimum_scalars'])}"
                    )
                if int(value["maximum_scalars"]) < int(value["maximum_octets"]):
                    scalar_conditions.append(
                        f"Observed_{component}_Scalar_Count > {ada_integer(value['maximum_scalars'])}"
                    )
                append_condition(lines, scalar_conditions, 12)
                lines.extend(
                    [
                        "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "               return;",
                        "            end if;",
                    ]
                )
        lines.append(f"            Seen_{component} := True;")
    lines.extend(
        [
            "         else",
            "            Status := Flyology_Wire.Codecs.Noncanonical;",
            "            return;",
            "         end if;",
            "      end loop;",
            "",
        ]
    )
    append_condition(lines, [f"not Seen_{field['component']}" for field in fields], 6)
    lines.extend(
        [
            "         Status := Flyology_Wire.Codecs.Invalid_Value;",
            "      else",
            "         Status := Flyology_Wire.Codecs.Decoded;",
            "      end if;",
            "   end Validate_For_Visit;",
            "",
            "   procedure Validate_And_Visit",
            "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
            "      Input  : Flyology_Wire.Octet_Array;",
            "      Status : out Flyology_Wire.Codecs.Decode_Status)",
            "   is",
            "      Reader        : Profile.Read_Cursor;",
            *(["      Nested        : Profile.Read_Cursor;"] if has_scalar else []),
            "      Previous      : Profile.Tag_Number := Profile.No_Tag;",
            "      Tag           : Profile.Field_Tag;",
            "      Region        : Profile.Extent;",
            "      Cursor_Result : Profile.Cursor_Status;",
            "      Read_Result   : Profile.Read_Status;",
            "      Valid_Status  : Flyology_Wire.Codecs.Decode_Status;",
        ]
    )
    for field in fields:
        component = field["component"]
        if field["kind"] == "scalar":
            lines.append(
                f"      Observed_{component} : {observer_value_type(field)};"
            )
        else:
            lines.extend(
                [
                    "",
                    f"      procedure Lend_{component} is new",
                    f"        Profile.Visit_Extent (Visit_{component});",
                ]
            )
    lines.extend(
        [
            "   begin",
            "      Validate_For_Visit (Writer, Input, Valid_Status);",
            "      if Valid_Status /= Flyology_Wire.Codecs.Decoded then",
            "         Status := Valid_Status;",
            "         return;",
            "      end if;",
            "",
            "      Profile.Initialize (Reader, Input);",
            "      while not Profile.At_End (Reader) loop",
            "         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);",
            "         if Read_Result /= Profile.Read then",
            "            Status := Map_Read_Error (Read_Result);",
            "            return;",
            "         end if;",
        ]
    )
    for index, field in enumerate(fields):
        component = field["component"]
        keyword = "if" if index == 0 else "elsif"
        lines.append(f"         {keyword} Tag = {component}_Tag then")
        if field["kind"] == "scalar":
            lines.extend(
                [
                    "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                    "            "
                    + scalar_read_call(
                        field["schema"]["value"], f"Observed_{component}", "Nested"
                    ),
                    "            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then",
                    "               Status := Map_Read_Error (Read_Result);",
                    "               return;",
                    "            end if;",
                    f"            Visit_{component} (Observed_{component});",
                ]
            )
        else:
            lines.extend(
                [
                    f"            Lend_{component} (Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                ]
            )
    lines.extend(
        [
            "         else",
            "            Status := Flyology_Wire.Codecs.Noncanonical;",
            "            return;",
            "         end if;",
            "      end loop;",
            "      Status := Flyology_Wire.Codecs.Decoded;",
            "   end Validate_And_Visit;",
        ]
    )


def render_variant_body(
    schema: dict[str, Any], binding: dict[str, Any], fields: list[dict[str, Any]]
) -> str:
    field = fields[0]
    component = field["component"]
    alternatives = field["alternatives"]
    members = [member for alternative in alternatives for member in alternative["fields"]]
    scalar_kinds = {member["schema"]["value"]["kind"] for member in members}
    package_name = binding["package_name"]
    lines = [
        "with Flyology_Wire.Profiles.Tagged_Profile;",
        "with Flyology_Wire.Sizes;",
        "with Interfaces;",
        "",
        f"package body {package_name} is",
        "   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;",
        "   package Sizes renames Flyology_Wire.Sizes;",
        "",
        "   use type Flyology_Wire.Codecs.Schema_Identity;",
        "   use type Flyology_Wire.Codecs.Measure_Status;",
        "   use type Flyology_Wire.Octet_Count;",
    ]
    if "signed" in scalar_kinds:
        lines.append("   use type Interfaces.Integer_64;")
    if "unsigned" in scalar_kinds:
        lines.append("   use type Interfaces.Unsigned_64;")
    lines.extend(
        [
            "   use type Profile.Cursor_Status;",
            "   use type Profile.Field_Tag;",
            "   use type Profile.Read_Status;",
            "   use type Profile.Write_Status;",
            "   use type Sizes.Arithmetic_Status;",
            "",
            f"   {component}_Tag : constant Profile.Field_Tag := {field['schema']['tag']};",
        ]
    )
    for alternative in alternatives:
        for member in alternative["fields"]:
            lines.append(
                f"   {member['symbol']}_Tag : constant Profile.Field_Tag := "
                f"{member['schema']['tag']};"
            )
    lines.extend(
        [
            "",
            f"   function Encoded_{component}_Tag (Item : Value) return Interfaces.Unsigned_64 is",
            "   begin",
            f"      case Item.{component} is",
        ]
    )
    for alternative in alternatives:
        lines.extend(
            [
                f"         when {alternative['literal']} =>",
                f"            return {alternative['tag']};",
            ]
        )
    lines.extend(["      end case;", f"   end Encoded_{component}_Tag;"])

    for alternative in alternatives:
        check_name = f"{component}_{alternative['name']}_Binding_Check"
        lines.append("")
        append_variant_value(
            lines,
            f"   {check_name} : constant Value :=",
            field,
            5,
            {component: alternative["literal"]},
        )
        lines.append(f"   pragma Unreferenced ({check_name});")
    for member in members:
        kind = member["schema"]["value"]["kind"]
        if kind == "boolean":
            continue
        type_name = "Interfaces.Unsigned_64" if kind == "unsigned" else "Interfaces.Integer_64"
        for bound in ("First", "Last"):
            check_name = f"{member['symbol']}_{bound}_Binding_Check"
            lines.append("")
            append_variant_value(
                lines,
                f"   {check_name} : constant Value :=",
                field,
                5,
                {member["component"]: f"{type_name}'{bound}"},
            )
            lines.append(f"   pragma Unreferenced ({check_name});")

    lines.extend(
        [
            "",
            f"   procedure Measure_{component}_Payload",
            "     (Item   : Value;",
            "      Size   : out Flyology_Wire.Byte_Count;",
            "      Status : out Flyology_Wire.Codecs.Measure_Status)",
            "   is",
            "      Arithmetic : Sizes.Arithmetic_Status := Sizes.Computed;",
            "      Field_Size : Flyology_Wire.Byte_Count;",
            "   begin",
            "      Size := 0;",
            f"      case Item.{component} is",
        ]
    )
    for alternative in alternatives:
        lines.append(f"         when {alternative['literal']} =>")
        invalid = []
        for member in alternative["fields"]:
            condition = scalar_invalid_expression(
                member["schema"]["value"], f"Item.{member['component']}"
            )
            if condition is not None:
                invalid.append(condition)
        if invalid:
            append_condition(lines, invalid, 12)
            lines.extend(
                [
                    "               Size := 0;",
                    "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "               return;",
                    "            end if;",
                ]
            )
        if not alternative["fields"]:
            lines.append("            null;")
        for member_index, member in enumerate(alternative["fields"]):
            value = member["schema"]["value"]
            expression = f"Item.{member['component']}"
            call = [
                "Profile.Measure_Field",
                f"  ({member['symbol']}_Tag,",
                f"   {scalar_size_expression(value, expression)},",
                "   Field_Size,",
                "   Arithmetic);",
            ]
            if member_index == 0:
                lines.extend(f"            {line}" for line in call)
            else:
                lines.append("            if Arithmetic = Sizes.Computed then")
                lines.extend(f"               {line}" for line in call)
                lines.append("            end if;")
            lines.extend(
                [
                    "            if Arithmetic = Sizes.Computed then",
                    "               Sizes.Accumulate (Size, Field_Size, Arithmetic);",
                    "            end if;",
                ]
            )
    lines.extend(
        [
            "      end case;",
            "      if Arithmetic = Sizes.Overflow then",
            "         Size := 0;",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "      else",
            "         Status := Flyology_Wire.Codecs.Measured;",
            "      end if;",
            f"   end Measure_{component}_Payload;",
            "",
            f"   procedure Measure_{component}_Value",
            "     (Item         : Value;",
            "      Size         : out Flyology_Wire.Byte_Count;",
            "      Payload_Size : out Flyology_Wire.Byte_Count;",
            "      Status       : out Flyology_Wire.Codecs.Measure_Status)",
            "   is",
            "      Arithmetic : Sizes.Arithmetic_Status := Sizes.Computed;",
            "      Framed_Size : Flyology_Wire.Byte_Count;",
            "   begin",
            "      Size := 0;",
            "      Payload_Size := 0;",
            f"      Measure_{component}_Payload (Item, Payload_Size, Status);",
            "      if Status /= Flyology_Wire.Codecs.Measured then",
            "         return;",
            "      end if;",
            f"      Size := Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Encoded_{component}_Tag (Item)));",
            "      Profile.Measure_Length_Delimited (Payload_Size, Framed_Size, Arithmetic);",
            "      if Arithmetic = Sizes.Computed then",
            "         Sizes.Accumulate (Size, Framed_Size, Arithmetic);",
            "      end if;",
            "      if Arithmetic = Sizes.Overflow then",
            "         Size := 0;",
            "         Payload_Size := 0;",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "      end if;",
            f"   end Measure_{component}_Value;",
            "",
            "   procedure Measure",
            "     (Item   : Value;",
            "      Size   : out Flyology_Wire.Byte_Count;",
            "      Status : out Flyology_Wire.Codecs.Measure_Status)",
            "   is",
            "      Arithmetic  : Sizes.Arithmetic_Status;",
            "      Field_Size : Flyology_Wire.Byte_Count;",
            "      Payload_Size : Flyology_Wire.Byte_Count;",
            "      Value_Size : Flyology_Wire.Byte_Count;",
            "   begin",
            "      Size := 0;",
            f"      if not Item.{component}'Valid then",
            "         Status := Flyology_Wire.Codecs.Invalid_Value;",
            "         return;",
            "      end if;",
            f"      Measure_{component}_Value (Item, Value_Size, Payload_Size, Status);",
            "      if Status /= Flyology_Wire.Codecs.Measured then",
            "         return;",
            "      end if;",
            f"      Profile.Measure_Field ({component}_Tag, Value_Size, Field_Size, Arithmetic);",
            "      if Arithmetic = Sizes.Computed then",
            "         Size := Field_Size;",
            "         Status := Flyology_Wire.Codecs.Measured;",
            "      else",
            "         Size := 0;",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "      end if;",
            "   end Measure;",
            "",
            "   procedure Encode",
            "     (Item    : Value;",
            "      Output  : in out Flyology_Wire.Octet_Array;",
            "      Written : out Flyology_Wire.Octet_Count;",
            "      Status  : out Flyology_Wire.Codecs.Encode_Status)",
            "   is",
            "      Size            : Flyology_Wire.Byte_Count;",
            "      Value_Size      : Flyology_Wire.Byte_Count;",
            "      Payload_Size    : Flyology_Wire.Byte_Count;",
            "      Measure_Result  : Flyology_Wire.Codecs.Measure_Status;",
            "      Writer          : Profile.Write_Cursor;",
            "      Nested          : Profile.Write_Cursor;",
            "      Payload_Writer  : Profile.Write_Cursor;",
            "      Scalar_Writer   : Profile.Write_Cursor;",
            "      Previous        : Profile.Tag_Number := Profile.No_Tag;",
            "      Payload_Previous : Profile.Tag_Number := Profile.No_Tag;",
            "      Region          : Profile.Extent;",
            "      Payload_Region  : Profile.Extent;",
            "      Scalar_Region   : Profile.Extent;",
            "      Cursor_Result   : Profile.Cursor_Status;",
            "      Write_Result    : Profile.Write_Status;",
            "   begin",
            "      Written := 0;",
            "      Measure (Item, Size, Measure_Result);",
            "      case Measure_Result is",
            "         when Flyology_Wire.Codecs.Invalid_Value =>",
            "            Status := Flyology_Wire.Codecs.Invalid_Value;",
            "            return;",
            "         when Flyology_Wire.Codecs.Size_Overflow =>",
            "            Status := Flyology_Wire.Codecs.Size_Overflow;",
            "            return;",
            "         when Flyology_Wire.Codecs.Measured =>",
            "            null;",
            "      end case;",
            "      if not Flyology_Wire.Fits_In_Buffer (Size)",
            "        or else Output'Length < Flyology_Wire.To_Octet_Count (Size)",
            "      then",
            "         Status := Flyology_Wire.Codecs.Destination_Too_Small;",
            "         return;",
            "      end if;",
            f"      Measure_{component}_Value (Item, Value_Size, Payload_Size, Measure_Result);",
            "      if Measure_Result /= Flyology_Wire.Codecs.Measured then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Region := (Start => 0, Length => Flyology_Wire.To_Octet_Count (Size));",
            "      Profile.Initialize (Writer, Output, Region, Cursor_Result);",
            "      if Cursor_Result /= Profile.Cursor_Ready then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Profile.Write_Field_Header",
            f"        (Output, Writer, Previous, {component}_Tag, Value_Size, Region, Write_Result);",
            "      if Write_Result /= Profile.Wrote then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Profile.Initialize (Nested, Output, Region, Cursor_Result);",
            "      if Cursor_Result /= Profile.Cursor_Ready then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            f"      Profile.Write_Unsigned (Output, Nested, Encoded_{component}_Tag (Item), Write_Result);",
            "      if Write_Result /= Profile.Wrote then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Profile.Write_Length_Delimited",
            "        (Output, Nested, Payload_Size, Payload_Region, Write_Result);",
            "      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Profile.Initialize (Payload_Writer, Output, Payload_Region, Cursor_Result);",
            "      if Cursor_Result /= Profile.Cursor_Ready then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            f"      case Item.{component} is",
        ]
    )
    for alternative in alternatives:
        lines.append(f"         when {alternative['literal']} =>")
        if not alternative["fields"]:
            lines.append("            null;")
        for member in alternative["fields"]:
            value = member["schema"]["value"]
            expression = f"Item.{member['component']}"
            lines.extend(
                [
                    "            Profile.Write_Field_Header",
                    f"              (Output, Payload_Writer, Payload_Previous, {member['symbol']}_Tag,",
                    f"               {scalar_size_expression(value, expression)},",
                    "               Scalar_Region, Write_Result);",
                    "            if Write_Result /= Profile.Wrote then",
                    "               Status := Flyology_Wire.Codecs.Size_Overflow;",
                    "               return;",
                    "            end if;",
                    "            Profile.Initialize (Scalar_Writer, Output, Scalar_Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Size_Overflow;",
                    "               return;",
                    "            end if;",
                    "            "
                    + scalar_write_call(value, expression, "Scalar_Writer"),
                    "            if Write_Result /= Profile.Wrote",
                    "              or else not Profile.At_End (Scalar_Writer)",
                    "            then",
                    "               Status := Flyology_Wire.Codecs.Size_Overflow;",
                    "               return;",
                    "            end if;",
                ]
            )
    lines.extend(
        [
            "      end case;",
            "      if not Profile.At_End (Payload_Writer) or else not Profile.At_End (Writer) then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Written := Profile.Consumed (Writer);",
            "      Status := Flyology_Wire.Codecs.Encoded;",
            "   end Encode;",
            "",
            "   function Map_Read_Error",
            "     (Status : Profile.Read_Status) return Flyology_Wire.Codecs.Decode_Status",
            "   is",
            "   begin",
            "      case Status is",
            "         when Profile.Truncated | Profile.Extent_Outside_Container =>",
            "            return Flyology_Wire.Codecs.Malformed;",
            "         when others =>",
            "            return Flyology_Wire.Codecs.Noncanonical;",
            "      end case;",
            "   end Map_Read_Error;",
            "",
            "   procedure Decode",
            "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
            "      Input  : Flyology_Wire.Octet_Array;",
            "      Item   : out Value;",
            "      Status : out Flyology_Wire.Codecs.Decode_Status)",
            "   is",
            "      Reader              : Profile.Read_Cursor;",
            "      Nested              : Profile.Read_Cursor;",
            "      Payload_Reader      : Profile.Read_Cursor;",
            "      Scalar_Reader       : Profile.Read_Cursor;",
            "      Previous            : Profile.Tag_Number := Profile.No_Tag;",
            "      Payload_Previous    : Profile.Tag_Number := Profile.No_Tag;",
            "      Tag                 : Profile.Field_Tag;",
            "      Payload_Tag         : Profile.Field_Tag;",
            "      Region              : Profile.Extent;",
            "      Payload_Region      : Profile.Extent;",
            "      Scalar_Region       : Profile.Extent;",
            "      Cursor_Result       : Profile.Cursor_Status;",
            "      Read_Result         : Profile.Read_Status;",
            f"      Raw_{component}_Tag : Interfaces.Unsigned_64;",
        ]
    )
    append_variant_value(lines, "      Candidate           : Value :=", field, 8)
    for member in members:
        kind = member["schema"]["value"]["kind"]
        if kind == "unsigned":
            lines.append(f"      Raw_{member['symbol']} : Interfaces.Unsigned_64;")
        elif kind == "signed":
            lines.append(f"      Raw_{member['symbol']} : Interfaces.Integer_64;")
        lines.append(f"      Seen_{member['symbol']} : Boolean := False;")
    lines.extend(
        [
            f"      Seen_{component} : Boolean := False;",
            "   begin",
        ]
    )
    append_variant_value(lines, "      Item :=", field, 8)
    lines.extend(
        [
            "      if Writer /= Local_Schema then",
            "         Status := Flyology_Wire.Codecs.Incompatible;",
            "         return;",
            "      end if;",
            "      Profile.Initialize (Reader, Input);",
            "      while not Profile.At_End (Reader) loop",
            "         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);",
            "         if Read_Result /= Profile.Read then",
            "            Status := Map_Read_Error (Read_Result);",
            "            return;",
            "         end if;",
            f"         if Tag = {component}_Tag then",
            "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
            "            if Cursor_Result /= Profile.Cursor_Ready then",
            "               Status := Flyology_Wire.Codecs.Malformed;",
            "               return;",
            "            end if;",
            f"            Profile.Read_Unsigned (Input, Nested, Raw_{component}_Tag, Read_Result);",
            "            if Read_Result /= Profile.Read then",
            "               Status := Map_Read_Error (Read_Result);",
            "               return;",
            "            end if;",
            "            Profile.Read_Length_Delimited",
            "              (Input, Nested, Payload_Region, Read_Result);",
            "            if Read_Result /= Profile.Read then",
            "               Status := Map_Read_Error (Read_Result);",
            "               return;",
            "            elsif not Profile.At_End (Nested) then",
            "               Status := Flyology_Wire.Codecs.Noncanonical;",
            "               return;",
            "            end if;",
            f"            case Raw_{component}_Tag is",
        ]
    )
    for alternative in alternatives:
        lines.extend(
            [
                f"               when {alternative['tag']} =>",
                f"                  Candidate.{component} := {alternative['literal']};",
                "                  Payload_Previous := Profile.No_Tag;",
                "                  Profile.Initialize",
                "                    (Payload_Reader, Input, Payload_Region, Cursor_Result);",
                "                  if Cursor_Result /= Profile.Cursor_Ready then",
                "                     Status := Flyology_Wire.Codecs.Malformed;",
                "                     return;",
                "                  end if;",
                "                  while not Profile.At_End (Payload_Reader) loop",
                "                     Profile.Read_Field_Header",
                "                       (Input, Payload_Reader, Payload_Previous, Payload_Tag,",
                "                        Scalar_Region, Read_Result);",
                "                     if Read_Result /= Profile.Read then",
                "                        Status := Map_Read_Error (Read_Result);",
                "                        return;",
                "                     end if;",
            ]
        )
        for member_index, member in enumerate(alternative["fields"]):
            keyword = "if" if member_index == 0 else "elsif"
            value = member["schema"]["value"]
            kind = value["kind"]
            target = (
                f"Candidate.{member['component']}"
                if kind == "boolean"
                else f"Raw_{member['symbol']}"
            )
            lines.extend(
                [
                    f"                     {keyword} Payload_Tag = {member['symbol']}_Tag then",
                    "                        Profile.Initialize",
                    "                          (Scalar_Reader, Input, Scalar_Region, Cursor_Result);",
                    "                        if Cursor_Result /= Profile.Cursor_Ready then",
                    "                           Status := Flyology_Wire.Codecs.Malformed;",
                    "                           return;",
                    "                        end if;",
                    "                        "
                    + scalar_read_call(value, target, "Scalar_Reader").replace(
                        " (Input, Scalar_Reader, ", "\n                          (Input, Scalar_Reader, "
                    ),
                    "                        if Read_Result /= Profile.Read",
                    "                          or else not Profile.At_End (Scalar_Reader)",
                    "                        then",
                    "                           Status := Map_Read_Error (Read_Result);",
                    "                           return;",
                    "                        end if;",
                ]
            )
            invalid = scalar_invalid_expression(value, target)
            if invalid is not None:
                lines.extend(
                    [
                        f"                        if {invalid} then",
                        "                           Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "                           return;",
                        "                        end if;",
                    ]
                )
            if kind != "boolean":
                lines.append(
                    f"                        Candidate.{member['component']} := {target};"
                )
            lines.append(f"                        Seen_{member['symbol']} := True;")
        if alternative["fields"]:
            lines.extend(
                [
                    "                     else",
                    "                        Status := Flyology_Wire.Codecs.Noncanonical;",
                    "                        return;",
                    "                     end if;",
                ]
            )
        else:
            lines.extend(
                [
                    "                     Status := Flyology_Wire.Codecs.Noncanonical;",
                    "                     return;",
                ]
            )
        lines.append("                  end loop;")
        if alternative["fields"]:
            append_condition(
                lines,
                [f"not Seen_{member['symbol']}" for member in alternative["fields"]],
                18,
            )
            lines.extend(
                [
                    "                     Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "                     return;",
                    "                  end if;",
                ]
            )
    lines.extend(
        [
            "               when others =>",
            "                  Status := Flyology_Wire.Codecs.Invalid_Value;",
            "                  return;",
            "            end case;",
            f"            Seen_{component} := True;",
            "         else",
            "            Status := Flyology_Wire.Codecs.Noncanonical;",
            "            return;",
            "         end if;",
            "      end loop;",
            f"      if not Seen_{component} then",
            "         Status := Flyology_Wire.Codecs.Invalid_Value;",
            "      else",
            "         Item := Candidate;",
            "         Status := Flyology_Wire.Codecs.Decoded;",
            "      end if;",
            "   end Decode;",
            f"end {package_name};",
        ]
    )
    return "\n".join(lines) + "\n"


def render_body(
    schema: dict[str, Any],
    binding: dict[str, Any],
    fields: list[dict[str, Any]],
    compatible: Optional[list[dict[str, Any]]] = None,
) -> str:
    compatible = compatible or []
    if any(field["kind"] == "variant" for field in fields):
        if compatible:
            raise Generator_Error(
                "$.fields: compatible-writer variants are not yet supported"
            )
        return render_variant_body(schema, binding, fields)
    package_name = binding["package_name"]
    scalars = bound_scalars(fields)
    lines = []
    if compatible:
        lines.append("with Flyology_Wire.Compatibility;")
    lines.extend(["with Flyology_Wire.Profiles.Tagged_Profile;", "with Flyology_Wire.Sizes;"])
    if scalars - {"boolean"} and not observer_uses_interfaces(fields):
        lines.append("with Interfaces;")
    lines.extend(["", f"package body {package_name} is"])
    if compatible:
        lines.extend(["   package Compatibility renames Flyology_Wire.Compatibility;", ""])
    lines.extend(
        [
            "   package Profile renames Flyology_Wire.Profiles.Tagged_Profile;",
            "   package Sizes renames Flyology_Wire.Sizes;",
            "",
            "   use type Flyology_Wire.Codecs.Schema_Identity;",
            "   use type Flyology_Wire.Octet_Count;",
        ]
    )
    if borrowed_observer_enabled(fields):
        lines.append("   use type Flyology_Wire.Codecs.Decode_Status;")
    if any(entry["ignored"] for entry in compatible) or any(
        field["kind"] in {"bytes", "text"} for field in fields
    ):
        lines.append("   use type Flyology_Wire.Byte_Count;")
    if any(field["kind"] == "sequence" for field in fields):
        lines.append("   use type Flyology_Wire.Codecs.Measure_Status;")
    if compatible:
        lines.append("   use type Compatibility.Schema_Relationship;")
    if "interfaces_integer_64" in scalars:
        lines.append("   use type Interfaces.Integer_64;")
    if "interfaces_unsigned_64" in scalars and any(
        field["kind"] != "enumeration" for field in fields
    ):
        lines.append("   use type Interfaces.Unsigned_64;")
    conversion_types = sorted(
        {
            field["conversion_type"]
            for field in fields
            if field["kind"] == "scalar" and field["conversion_type"] is not None
        },
        key=str.lower,
    )
    lines.extend(f"   use type {conversion_type};" for conversion_type in conversion_types)
    if any(field["kind"] == "text" for field in fields):
        lines.append("   use type Profile.UTF_8_Status;")
    lines.extend(
        [
        "   use type Profile.Cursor_Status;",
        "   use type Profile.Field_Tag;",
        "   use type Profile.Read_Status;",
        "   use type Profile.Write_Status;",
        "   use type Sizes.Arithmetic_Status;",
        "",
        ]
    )
    tag_width = max(len(f"{field['component']}_Tag") for field in fields)
    for field in fields:
        name = f"{field['component']}_Tag"
        lines.append(f"   {name.ljust(tag_width)} : constant Profile.Field_Tag := {field['schema']['tag']};")
    for field in fields:
        if field["kind"] != "enumeration":
            continue
        component = field["component"]
        lines.extend(
            [
                "",
                f"   function Encoded_{component}_Tag (Item : Value) return Interfaces.Unsigned_64 is",
                "   begin",
                f"      case Item.{component} is",
            ]
        )
        for literal in field["literals"]:
            lines.extend(
                [
                    f"         when {literal['literal']} =>",
                    f"            return {literal['tag']};",
                ]
            )
        lines.extend(["      end case;", f"   end Encoded_{component}_Tag;"])
    ignored_tags = sorted({tag for entry in compatible for tag in entry["ignored"]})
    for tag in ignored_tags:
        lines.append(f"   Ignored_Writer_Tag_{tag} : constant Profile.Field_Tag := {tag};")
    if compatible:
        accepted = ", ".join(
            f"{index} => Accepted_Writer_{index}_Schema"
            for index in range(1, len(compatible) + 1)
        )
        lines.extend(
            [
                "",
                "   Accepted_Writers : constant Compatibility.Schema_Identity_Array :=",
                f"     [{accepted}];",
            ]
        )
    for field in fields:
        component = field["component"]
        if field["kind"] == "scalar":
            kind = field["schema"]["value"]["kind"]
            if kind == "boolean":
                continue
            if field["conversion_type"] is None:
                checks = [(component, interface_scalar_bounds(kind))]
            else:
                value = field["schema"]["value"]
                conversion_type = field["conversion_type"]
                minimum = ada_integer(value["minimum"])
                maximum = ada_integer(value["maximum"])
                lines.extend(
                    [
                        "",
                        "   pragma",
                        "     Compile_Time_Error",
                        f"       ({conversion_type}'First /= {minimum}",
                        f"          or else {conversion_type}'Last /= {maximum},",
                        f'        "{component} application type differs from its wire-schema range");',
                    ]
                )
                checks = [
                    (
                        component,
                        (
                            (
                                "Minimum",
                                f"{conversion_type} ({minimum})",
                            ),
                            (
                                "Maximum",
                                f"{conversion_type} ({maximum})",
                            ),
                        ),
                    )
                ]
        elif field["kind"] == "enumeration":
            checks = []
            for literal in field["literals"]:
                check_name = f"{component}_{literal['name']}_Binding_Check"
                lines.append("")
                append_value(
                    lines,
                    f"   {check_name} : constant Value :=",
                    fields,
                    5,
                    {component: literal["literal"]},
                )
                lines.append(f"   pragma Unreferenced ({check_name});")
        elif field["kind"] in {"bytes", "text"}:
            checks = [(field["length_component"], interface_scalar_bounds("unsigned"))]
            maximum = ada_integer(field["schema"]["value"]["maximum_octets"])
            lower = ada_integer(field["schema"]["value"]["construction_lower_bound"])
            capacity_name = f"{component}_Capacity_Binding_Check"
            lines.append("")
            append_value(lines, f"   {capacity_name} : constant Value :=", fields, 5)
            lines.extend(
                [
                    "   pragma",
                    "     Compile_Time_Error",
                    f"       ({capacity_name}.{component}'Length < {maximum},",
                    f'        "{component} capacity is below its wire-schema maximum");',
                    "   pragma",
                    "     Compile_Time_Error",
                    f"       ({capacity_name}.{component}'First /= {lower},",
                    f'        "{component} lower bound differs from its wire construction bound");',
                ]
            )
        else:
            element_kind = field["schema"]["value"]["element"]["kind"]
            checks = [(field["length_component"], interface_scalar_bounds("unsigned"))]
            if element_kind != "boolean":
                checks.append((component, interface_scalar_bounds(element_kind)))
            maximum = ada_integer(
                field["schema"]["value"]["dimensions"][0]["maximum_count"]
            )
            lower = ada_integer(
                field["schema"]["value"]["dimensions"][0]["construction_lower_bound"]
            )
            capacity_name = f"{component}_Capacity_Binding_Check"
            lines.append("")
            append_value(lines, f"   {capacity_name} : constant Value :=", fields, 5)
            lines.extend(
                [
                    "   pragma",
                    "     Compile_Time_Error",
                    f"       ({capacity_name}.{component}'Length < {maximum},",
                    f'        "{component} capacity is below its wire-schema maximum");',
                    "   pragma",
                    "     Compile_Time_Error",
                    f"       ({capacity_name}.{component}'First /= {lower},",
                    f'        "{component} lower bound differs from its wire construction bound");',
                ]
            )
        for checked_component, bounds in checks:
            for bound, value in bounds:
                lines.append("")
                check_name = f"{checked_component}_{bound}_Binding_Check"
                if field["kind"] == "sequence" and checked_component == component:
                    value = f"[others => {value}]"
                append_value(
                    lines,
                    f"   {check_name} : constant Value :=",
                    fields,
                    5,
                    {checked_component: value},
                )
                lines.append(f"   pragma Unreferenced ({check_name});")
    for field in fields:
        if field["kind"] != "sequence":
            continue
        component = field["component"]
        length_component = field["length_component"]
        sequence = field["schema"]["value"]
        dimension = sequence["dimensions"][0]
        element = sequence["element"]
        lines.extend(
            [
                "",
                f"   procedure Measure_{component}_Value",
                "     (Item   : Value;",
                "      Size   : out Flyology_Wire.Byte_Count;",
                "      Status : out Flyology_Wire.Codecs.Measure_Status)",
                "   is",
                "      Arithmetic  : Sizes.Arithmetic_Status := Sizes.Computed;",
                "      Element_Size : Flyology_Wire.Byte_Count;",
                f"      Remaining   : Interfaces.Unsigned_64 := Item.{length_component};",
                "   begin",
                f"      Size := Flyology_Wire.Byte_Count (Profile.Unsigned_Size (Item.{length_component}));",
            ]
        )
        count_conditions = []
        if int(dimension["minimum_count"]) > 0:
            count_conditions.append(
                f"Item.{length_component} < {ada_integer(dimension['minimum_count'])}"
            )
        if int(dimension["maximum_count"]) < schema_lock.U64_MAX:
            count_conditions.append(
                f"Item.{length_component} > {ada_integer(dimension['maximum_count'])}"
            )
        count_conditions.append(
            f"Item.{length_component} > Interfaces.Unsigned_64 (Item.{component}'Length)"
        )
        append_condition(lines, count_conditions, 6)
        lines.extend(
            [
                "         Size := 0;",
                "         Status := Flyology_Wire.Codecs.Invalid_Value;",
                "         return;",
                "      end if;",
                f"      for Element of Item.{component} loop",
                "         exit when Remaining = 0 or else Arithmetic /= Sizes.Computed;",
            ]
        )
        invalid_element = scalar_invalid_expression(element, "Element")
        if invalid_element is not None:
            lines.extend(
                [
                    f"         if {invalid_element} then",
                    "            Size := 0;",
                    "            Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "            return;",
                    "         end if;",
                ]
            )
        lines.extend(
            [
                "         Profile.Measure_Length_Delimited",
                f"           ({scalar_size_expression(element, 'Element')}, Element_Size, Arithmetic);",
                "         if Arithmetic = Sizes.Computed then",
                "            Sizes.Accumulate (Size, Element_Size, Arithmetic);",
                "         end if;",
                "         Remaining := Remaining - 1;",
                "      end loop;",
                "      if Arithmetic = Sizes.Overflow then",
                "         Size := 0;",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "      elsif Remaining /= 0 then",
                "         Size := 0;",
                "         Status := Flyology_Wire.Codecs.Invalid_Value;",
                "      else",
                "         Status := Flyology_Wire.Codecs.Measured;",
                "      end if;",
                f"   end Measure_{component}_Value;",
            ]
        )
    lines.extend(
        [
            "",
            "   procedure Measure",
            "     (Item   : Value;",
            "      Size   : out Flyology_Wire.Byte_Count;",
            "      Status : out Flyology_Wire.Codecs.Measure_Status)",
            "   is",
            "      Arithmetic : Sizes.Arithmetic_Status"
            + (" := Sizes.Computed;" if include_expression(fields[0]) is not None else ";"),
            "      Field_Size : Flyology_Wire.Byte_Count;",
        ]
    )
    for field in fields:
        if field["kind"] == "sequence":
            component = field["component"]
            lines.extend(
                [
                    f"      {component}_Value_Size : Flyology_Wire.Byte_Count;",
                    f"      {component}_Measure_Status : Flyology_Wire.Codecs.Measure_Status;",
                ]
            )
        elif field["kind"] == "text":
            component = field["component"]
            lines.extend(
                [
                    f"      {component}_Scalar_Count : Flyology_Wire.Octet_Count;",
                    f"      {component}_UTF_8_Status : Profile.UTF_8_Status;",
                ]
            )
    lines.extend(["   begin", "      Size := 0;"])
    invalid = []
    for field in fields:
        if field["kind"] == "enumeration":
            invalid.append(f"not Item.{field['component']}'Valid")
            continue
        if field["kind"] in {"bytes", "text"}:
            value = field["schema"]["value"]
            length = f"Item.{field['length_component']}"
            if int(value["minimum_octets"]) > 0:
                invalid.append(f"{length} < {ada_integer(value['minimum_octets'])}")
            if int(value["maximum_octets"]) < schema_lock.U64_MAX:
                invalid.append(f"{length} > {ada_integer(value['maximum_octets'])}")
            invalid.append(
                f"{length} > Interfaces.Unsigned_64 (Item.{field['component']}'Length)"
            )
            continue
        if field["kind"] != "scalar":
            continue
        if field["conversion_type"] is not None:
            continue
        expression = invalid_expression(field, f"Item.{field['component']}")
        if expression is None:
            continue
        if field["present_component"] is not None:
            expression = f"Item.{field['present_component']} and then ({expression})"
        invalid.append(expression)
    if invalid:
        append_condition(lines, invalid, 6)
        lines.extend(
            [
                "         Status := Flyology_Wire.Codecs.Invalid_Value;",
                "         return;",
                "      end if;",
                "",
            ]
        )
    for field in fields:
        if field["kind"] != "text":
            continue
        component = field["component"]
        length_component = field["length_component"]
        value = field["schema"]["value"]
        lines.extend(
            [
                f"      Profile.Validate_UTF_8 (Item.{component},",
                "                              (Start  => 0,",
                f"                               Length => Flyology_Wire.Octet_Count (Item.{length_component})),",
                f"                              {component}_Scalar_Count,",
                f"                              {component}_UTF_8_Status);",
            ]
        )
        scalar_conditions = [
            f"{component}_UTF_8_Status /= Profile.Valid_UTF_8"
        ]
        if int(value["minimum_scalars"]) > 0:
            scalar_conditions.append(
                f"{component}_Scalar_Count < {ada_integer(value['minimum_scalars'])}"
            )
        if int(value["maximum_scalars"]) < int(value["maximum_octets"]):
            scalar_conditions.append(
                f"{component}_Scalar_Count > {ada_integer(value['maximum_scalars'])}"
            )
        append_condition(lines, scalar_conditions, 6)
        lines.extend(
            [
                "         Status := Flyology_Wire.Codecs.Invalid_Value;",
                "         return;",
                "      end if;",
                "",
            ]
        )
    for index, field in enumerate(fields):
        if field["kind"] == "scalar":
            call = [
                "Profile.Measure_Field",
                f"  ({field['component']}_Tag,",
                *size_argument_lines(field, "   "),
                "   Field_Size,",
                "   Arithmetic);",
            ]
            prelude: list[str] = []
        elif field["kind"] == "enumeration":
            component = field["component"]
            prelude = []
            call = [
                "Profile.Measure_Field",
                f"  ({component}_Tag,",
                "   Flyology_Wire.Byte_Count",
                f"     (Profile.Unsigned_Size (Encoded_{component}_Tag (Item))),",
                "   Field_Size,",
                "   Arithmetic);",
            ]
        elif field["kind"] == "sequence":
            component = field["component"]
            prelude = [
                f"Measure_{component}_Value (Item, {component}_Value_Size, {component}_Measure_Status);",
                f"if {component}_Measure_Status /= Flyology_Wire.Codecs.Measured then",
                "   Size := 0;",
                f"   Status := {component}_Measure_Status;",
                "   return;",
                "end if;",
            ]
            call = [
                "Profile.Measure_Field",
                f"  ({component}_Tag,",
                f"   {component}_Value_Size,",
                "   Field_Size,",
                "   Arithmetic);",
            ]
        else:
            component = field["component"]
            prelude = []
            call = [
                "Profile.Measure_Field",
                f"  ({component}_Tag,",
                f"   Flyology_Wire.Byte_Count (Item.{field['length_component']}),",
                "   Field_Size,",
                "   Arithmetic);",
            ]
        include = include_expression(field)
        if include is not None:
            condition = include if index == 0 else f"Arithmetic = Sizes.Computed and then {include}"
            lines.append(f"      if {condition} then")
            lines.extend(f"         {line}" for line in prelude)
            lines.extend(f"         {line}" for line in call)
            lines.extend(
                [
                    "         if Arithmetic = Sizes.Computed then",
                    "            Sizes.Accumulate (Size, Field_Size, Arithmetic);",
                    "         end if;",
                    "      end if;",
                ]
            )
        elif index == 0:
            lines.extend(f"      {line}" for line in prelude)
            lines.extend(f"      {line}" for line in call)
            lines.extend(
                [
                    "      if Arithmetic = Sizes.Computed then",
                    "         Sizes.Accumulate (Size, Field_Size, Arithmetic);",
                    "      end if;",
                ]
            )
        else:
            lines.append("      if Arithmetic = Sizes.Computed then")
            lines.extend(f"         {line}" for line in prelude)
            lines.extend(f"         {line}" for line in call)
            lines.append("      end if;")
            lines.extend(
                [
                    "      if Arithmetic = Sizes.Computed then",
                    "         Sizes.Accumulate (Size, Field_Size, Arithmetic);",
                    "      end if;",
                ]
            )
    lines.extend(
        [
            "      if Arithmetic = Sizes.Overflow then",
            "         Size := 0;",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "      else",
            "         Status := Flyology_Wire.Codecs.Measured;",
            "      end if;",
            "   end Measure;",
            "",
            "   procedure Encode",
            "     (Item    : Value;",
            "      Output  : in out Flyology_Wire.Octet_Array;",
            "      Written : out Flyology_Wire.Octet_Count;",
            "      Status  : out Flyology_Wire.Codecs.Encode_Status)",
            "   is",
            "      Size           : Flyology_Wire.Byte_Count;",
            "      Measure_Result : Flyology_Wire.Codecs.Measure_Status;",
            "      Writer         : Profile.Write_Cursor;",
            "      Nested         : Profile.Write_Cursor;",
            "      Previous       : Profile.Tag_Number := Profile.No_Tag;",
            "      Region         : Profile.Extent;",
            "      Cursor_Result  : Profile.Cursor_Status;",
            "      Write_Result   : Profile.Write_Status;",
        ]
    )
    for field in fields:
        if field["kind"] == "sequence":
            component = field["component"]
            lines.extend(
                [
                    f"      {component}_Value_Size : Flyology_Wire.Byte_Count;",
                    f"      {component}_Measure_Status : Flyology_Wire.Codecs.Measure_Status;",
                    f"      {component}_Element_Writer : Profile.Write_Cursor;",
                    f"      {component}_Element_Region : Profile.Extent;",
                    f"      {component}_Remaining : Interfaces.Unsigned_64;",
                ]
            )
    lines.extend(
        [
            "   begin",
            "      Written := 0;",
            "      Measure (Item, Size, Measure_Result);",
            "      case Measure_Result is",
            "         when Flyology_Wire.Codecs.Invalid_Value =>",
            "            Status := Flyology_Wire.Codecs.Invalid_Value;",
            "            return;",
            "",
            "         when Flyology_Wire.Codecs.Size_Overflow =>",
            "            Status := Flyology_Wire.Codecs.Size_Overflow;",
            "            return;",
            "",
            "         when Flyology_Wire.Codecs.Measured      =>",
            "            null;",
            "      end case;",
            "      if not Flyology_Wire.Fits_In_Buffer (Size)",
            "        or else Output'Length < Flyology_Wire.To_Octet_Count (Size)",
            "      then",
            "         Status := Flyology_Wire.Codecs.Destination_Too_Small;",
            "         return;",
            "      end if;",
            "",
            "      Region := (Start => 0, Length => Flyology_Wire.To_Octet_Count (Size));",
            "      Profile.Initialize (Writer, Output, Region, Cursor_Result);",
            "      if Cursor_Result /= Profile.Cursor_Ready then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
        ]
    )
    for field in fields:
        if field["kind"] == "scalar":
            block = [
                "      Profile.Write_Field_Header",
                "        (Output,",
                "         Writer,",
                "         Previous,",
                f"         {field['component']}_Tag,",
                *size_argument_lines(field, "         "),
                "         Region,",
                "         Write_Result);",
                "      if Write_Result /= Profile.Wrote then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                "      Profile.Initialize (Nested, Output, Region, Cursor_Result);",
                "      if Cursor_Result /= Profile.Cursor_Ready then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                f"      {write_call(field)}",
                "      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
            ]
        elif field["kind"] == "enumeration":
            component = field["component"]
            block = [
                "      Profile.Write_Field_Header",
                "        (Output,",
                "         Writer,",
                "         Previous,",
                f"         {component}_Tag,",
                "         Flyology_Wire.Byte_Count",
                f"           (Profile.Unsigned_Size (Encoded_{component}_Tag (Item))),",
                "         Region,",
                "         Write_Result);",
                "      if Write_Result /= Profile.Wrote then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                "      Profile.Initialize (Nested, Output, Region, Cursor_Result);",
                "      if Cursor_Result /= Profile.Cursor_Ready then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                f"      Profile.Write_Unsigned (Output, Nested, Encoded_{component}_Tag (Item),",
                "                              Write_Result);",
                "      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
            ]
        elif field["kind"] in {"bytes", "text"}:
            component = field["component"]
            length_component = field["length_component"]
            block = [
                "      Profile.Write_Field_Header",
                "        (Output,",
                "         Writer,",
                "         Previous,",
                f"         {component}_Tag,",
                f"         Flyology_Wire.Byte_Count (Item.{length_component}),",
                "         Region,",
                "         Write_Result);",
                "      if Write_Result /= Profile.Wrote then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                "      Profile.Initialize (Nested, Output, Region, Cursor_Result);",
                "      if Cursor_Result /= Profile.Cursor_Ready then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                f"      Profile.Write_Octets (Output, Nested, Item.{component},",
                f"                            Flyology_Wire.Octet_Count (Item.{length_component}),",
                "                            Write_Result);",
                "      if Write_Result /= Profile.Wrote or else not Profile.At_End (Nested) then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
            ]
        else:
            component = field["component"]
            length_component = field["length_component"]
            element = field["schema"]["value"]["element"]
            element_size = scalar_size_expression(element, "Element")
            block = [
                f"      Measure_{component}_Value",
                f"        (Item, {component}_Value_Size, {component}_Measure_Status);",
                f"      case {component}_Measure_Status is",
                "         when Flyology_Wire.Codecs.Invalid_Value =>",
                "            Status := Flyology_Wire.Codecs.Invalid_Value;",
                "            return;",
                "         when Flyology_Wire.Codecs.Size_Overflow =>",
                "            Status := Flyology_Wire.Codecs.Size_Overflow;",
                "            return;",
                "         when Flyology_Wire.Codecs.Measured =>",
                "            null;",
                "      end case;",
                "      Profile.Write_Field_Header",
                "        (Output,",
                "         Writer,",
                "         Previous,",
                f"         {component}_Tag,",
                f"         {component}_Value_Size,",
                "         Region,",
                "         Write_Result);",
                "      if Write_Result /= Profile.Wrote then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                "      Profile.Initialize (Nested, Output, Region, Cursor_Result);",
                "      if Cursor_Result /= Profile.Cursor_Ready then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                f"      Profile.Write_Unsigned (Output, Nested, Item.{length_component}, Write_Result);",
                "      if Write_Result /= Profile.Wrote then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
                f"      {component}_Remaining := Item.{length_component};",
                f"      for Element of Item.{component} loop",
                f"         exit when {component}_Remaining = 0;",
                "         Profile.Write_Length_Delimited",
                "           (Output,",
                "            Nested,",
                f"            {element_size},",
                f"            {component}_Element_Region,",
                "            Write_Result);",
                "         if Write_Result /= Profile.Wrote then",
                "            Status := Flyology_Wire.Codecs.Size_Overflow;",
                "            return;",
                "         end if;",
                "         Profile.Initialize",
                f"           ({component}_Element_Writer,",
                "            Output,",
                f"            {component}_Element_Region,",
                "            Cursor_Result);",
                "         if Cursor_Result /= Profile.Cursor_Ready then",
                "            Status := Flyology_Wire.Codecs.Size_Overflow;",
                "            return;",
                "         end if;",
                "         " + scalar_write_call(element, "Element", f"{component}_Element_Writer"),
                "         if Write_Result /= Profile.Wrote",
                f"           or else not Profile.At_End ({component}_Element_Writer)",
                "         then",
                "            Status := Flyology_Wire.Codecs.Size_Overflow;",
                "            return;",
                "         end if;",
                f"         {component}_Remaining := {component}_Remaining - 1;",
                "      end loop;",
                f"      if {component}_Remaining /= 0 or else not Profile.At_End (Nested) then",
                "         Status := Flyology_Wire.Codecs.Size_Overflow;",
                "         return;",
                "      end if;",
            ]
        include = include_expression(field)
        if include is None:
            lines.extend(block)
        else:
            lines.append(f"      if {include} then")
            lines.extend("   " + line for line in block)
            lines.append("      end if;")
    lines.extend(
        [
            "      if not Profile.At_End (Writer) then",
            "         Status := Flyology_Wire.Codecs.Size_Overflow;",
            "         return;",
            "      end if;",
            "      Written := Profile.Consumed (Writer);",
            "      Status := Flyology_Wire.Codecs.Encoded;",
            "   end Encode;",
            "",
            "   function Map_Read_Error",
            "     (Status : Profile.Read_Status) return Flyology_Wire.Codecs.Decode_Status",
            "   is",
            "   begin",
            "      case Status is",
            "         when Profile.Truncated | Profile.Extent_Outside_Container =>",
            "            return Flyology_Wire.Codecs.Malformed;",
            "",
            "         when others                                               =>",
            "            return Flyology_Wire.Codecs.Noncanonical;",
            "      end case;",
            "   end Map_Read_Error;",
            "",
            "   procedure Decode",
            "     (Writer : Flyology_Wire.Codecs.Schema_Identity;",
            "      Input  : Flyology_Wire.Octet_Array;",
            "      Item   : out Value;",
            "      Status : out Flyology_Wire.Codecs.Decode_Status)",
            "   is",
        ]
    )
    if compatible:
        lines.extend(
            [
                "      Relationship  : constant Compatibility.Schema_Relationship :=",
                "        Compatibility.Classify (Local_Schema, Writer, Accepted_Writers);",
            ]
        )
    lines.extend(
        [
            "      Reader        : Profile.Read_Cursor;",
            "      Nested        : Profile.Read_Cursor;",
            "      Previous      : Profile.Tag_Number := Profile.No_Tag;",
            "      Tag           : Profile.Field_Tag;",
            "      Region        : Profile.Extent;",
            "      Cursor_Result : Profile.Cursor_Status;",
            "      Read_Result   : Profile.Read_Status;",
        ]
    )
    append_value(lines, "      Candidate     : Value :=", fields, 8)
    for field in fields:
        component = field["component"]
        if field["kind"] == "scalar":
            kind = field["schema"]["value"]["kind"]
            if kind == "unsigned":
                lines.append(f"      Raw_{component} : Interfaces.Unsigned_64;")
            elif kind == "signed":
                lines.append(f"      Raw_{component} : Interfaces.Integer_64;")
            continue
        if field["kind"] == "enumeration":
            lines.append(f"      Raw_{component} : Interfaces.Unsigned_64;")
            continue
        if field["kind"] in {"bytes", "text"}:
            if field["kind"] == "text":
                lines.extend(
                    [
                        f"      {component}_Scalar_Count : Flyology_Wire.Octet_Count;",
                        f"      {component}_UTF_8_Status : Profile.UTF_8_Status;",
                    ]
                )
            continue
        element_kind = field["schema"]["value"]["element"]["kind"]
        lines.extend(
            [
                f"      Raw_{component}_Length : Interfaces.Unsigned_64;",
                f"      {component}_Element_Reader : Profile.Read_Cursor;",
                f"      {component}_Element_Region : Profile.Extent;",
                f"      {component}_Remaining : Interfaces.Unsigned_64;",
            ]
        )
        if element_kind == "unsigned":
            lines.append(f"      Raw_{component}_Element : Interfaces.Unsigned_64;")
        elif element_kind == "signed":
            lines.append(f"      Raw_{component}_Element : Interfaces.Integer_64;")
    tracked_fields = [field for field in fields if field["presence"] != "optional"]
    seen_width = max((len(f"Seen_{field['component']}") for field in tracked_fields), default=0)
    for field in tracked_fields:
        name = f"Seen_{field['component']}"
        lines.append(f"      {name.ljust(seen_width)} : Boolean := False;")
    lines.extend(
        [
            "   begin",
        ]
    )
    append_value(lines, "      Item :=", fields, 8)
    lines.extend(
        [
            (
                "      if Relationship not in Compatibility.Exact | Compatibility.Compatible then"
                if compatible
                else "      if Writer /= Local_Schema then"
            ),
            "         Status := Flyology_Wire.Codecs.Incompatible;",
            "         return;",
            "      end if;",
            "",
            "      Profile.Initialize (Reader, Input);",
            "      while not Profile.At_End (Reader) loop",
            "         Profile.Read_Field_Header (Input, Reader, Previous, Tag, Region, Read_Result);",
            "         if Read_Result /= Profile.Read then",
            "            Status := Map_Read_Error (Read_Result);",
            "            return;",
            "         end if;",
            "",
        ]
    )
    for index, field in enumerate(fields):
        keyword = "if" if index == 0 else "elsif"
        tag = field["schema"]["tag"]
        lines.append(f"         {keyword} Tag = {field['component']}_Tag then")
        prohibited_writers = [
            accepted_index
            for accepted_index, entry in enumerate(compatible, 1)
            if tag not in {item["tag"] for item in entry["schema"]["root"]["fields"]}
        ]
        if prohibited_writers:
            append_condition(
                lines,
                [
                    f"Writer = Accepted_Writer_{accepted_index}_Schema"
                    for accepted_index in prohibited_writers
                ],
                12,
            )
            lines.extend(
                [
                    "               Status := Flyology_Wire.Codecs.Noncanonical;",
                    "               return;",
                    "            end if;",
                ]
            )
        if field["kind"] == "scalar":
            kind = field["schema"]["value"]["kind"]
            target = (
                f"Candidate.{field['component']}"
                if kind == "boolean"
                else f"Raw_{field['component']}"
            )
            lines.extend(
                [
                "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                "            if Cursor_Result /= Profile.Cursor_Ready then",
                "               Status := Flyology_Wire.Codecs.Malformed;",
                "               return;",
                "            end if;",
                f"            {read_call(field, target)}",
                "            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then",
                "               Status := Map_Read_Error (Read_Result);",
                "               return;",
                "            end if;",
                ]
            )
            invalid_candidate = invalid_expression(field, target)
            if invalid_candidate is not None:
                lines.extend(
                    [
                    f"            if {invalid_candidate} then",
                    "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "               return;",
                    "            end if;",
                    ]
                )
            if field["default"] is not None:
                lines.extend(
                    [
                    f"            if {target} = {field['default']} then",
                    "               Status := Flyology_Wire.Codecs.Noncanonical;",
                    "               return;",
                    "            end if;",
                    ]
                )
            if kind != "boolean":
                value = f"Raw_{field['component']}"
                if field["conversion_type"] is not None:
                    value = f"{field['conversion_type']} ({value})"
                lines.append(f"            Candidate.{field['component']} := {value};")
            if field["present_component"] is not None:
                lines.append(f"            Candidate.{field['present_component']} := True;")
        elif field["kind"] == "enumeration":
            component = field["component"]
            lines.extend(
                [
                    "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                    f"            Profile.Read_Unsigned (Input, Nested, Raw_{component}, Read_Result);",
                    "            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then",
                    "               Status := Map_Read_Error (Read_Result);",
                    "               return;",
                    "            end if;",
                    f"            case Raw_{component} is",
                ]
            )
            for literal in field["literals"]:
                lines.extend(
                    [
                        f"               when {literal['tag']} =>",
                        f"                  Candidate.{component} := {literal['literal']};",
                    ]
                )
            lines.extend(
                [
                    "               when others =>",
                    "                  Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "                  return;",
                    "            end case;",
                ]
            )
        elif field["kind"] in {"bytes", "text"}:
            component = field["component"]
            length_component = field["length_component"]
            value = field["schema"]["value"]
            conditions = []
            if int(value["minimum_octets"]) > 0:
                conditions.append(
                    f"Flyology_Wire.Byte_Count (Region.Length) < {ada_integer(value['minimum_octets'])}"
                )
            if int(value["maximum_octets"]) < schema_lock.U64_MAX:
                conditions.append(
                    f"Flyology_Wire.Byte_Count (Region.Length) > {ada_integer(value['maximum_octets'])}"
                )
            conditions.append(f"Region.Length > Candidate.{component}'Length")
            if conditions:
                append_condition(lines, conditions, 12)
                lines.extend(
                    [
                        "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "               return;",
                        "            end if;",
                    ]
                )
            if field["kind"] == "text":
                lines.extend(
                    [
                        "            Profile.Validate_UTF_8",
                        f"              (Input, Region, {component}_Scalar_Count, {component}_UTF_8_Status);",
                    ]
                )
                scalar_conditions = [
                    f"{component}_UTF_8_Status /= Profile.Valid_UTF_8"
                ]
                if int(value["minimum_scalars"]) > 0:
                    scalar_conditions.append(
                        f"{component}_Scalar_Count < {ada_integer(value['minimum_scalars'])}"
                    )
                if int(value["maximum_scalars"]) < int(value["maximum_octets"]):
                    scalar_conditions.append(
                        f"{component}_Scalar_Count > {ada_integer(value['maximum_scalars'])}"
                    )
                append_condition(lines, scalar_conditions, 12)
                lines.extend(
                    [
                        "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "               return;",
                        "            end if;",
                    ]
                )
            lines.extend(
                [
                    "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                    f"            Profile.Read_Octets (Input, Nested, Candidate.{component},",
                    "                                 Region.Length, Read_Result);",
                    "            if Read_Result /= Profile.Read or else not Profile.At_End (Nested) then",
                    "               Status := Map_Read_Error (Read_Result);",
                    "               return;",
                    "            end if;",
                    f"            Candidate.{length_component} := Interfaces.Unsigned_64 (Region.Length);",
                ]
            )
        else:
            component = field["component"]
            length_component = field["length_component"]
            sequence = field["schema"]["value"]
            dimension = sequence["dimensions"][0]
            element = sequence["element"]
            element_kind = element["kind"]
            element_target = "Element" if element_kind == "boolean" else f"Raw_{component}_Element"
            lines.extend(
                [
                    "            Profile.Initialize (Nested, Input, Region, Cursor_Result);",
                    "            if Cursor_Result /= Profile.Cursor_Ready then",
                    "               Status := Flyology_Wire.Codecs.Malformed;",
                    "               return;",
                    "            end if;",
                    f"            Profile.Read_Unsigned (Input, Nested, Raw_{component}_Length, Read_Result);",
                    "            if Read_Result /= Profile.Read then",
                    "               Status := Map_Read_Error (Read_Result);",
                    "               return;",
                    "            end if;",
                ]
            )
            count_conditions = []
            if int(dimension["minimum_count"]) > 0:
                count_conditions.append(
                    f"Raw_{component}_Length < {ada_integer(dimension['minimum_count'])}"
                )
            if int(dimension["maximum_count"]) < schema_lock.U64_MAX:
                count_conditions.append(
                    f"Raw_{component}_Length > {ada_integer(dimension['maximum_count'])}"
                )
            count_conditions.append(
                f"Raw_{component}_Length > Interfaces.Unsigned_64 (Candidate.{component}'Length)"
            )
            append_condition(lines, count_conditions, 12)
            lines.extend(
                [
                    "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "               return;",
                    "            end if;",
                    f"            Candidate.{length_component} := Raw_{component}_Length;",
                    f"            {component}_Remaining := Raw_{component}_Length;",
                    f"            for Element of Candidate.{component} loop",
                    f"               exit when {component}_Remaining = 0;",
                    "               Profile.Read_Length_Delimited",
                    f"                 (Input, Nested, {component}_Element_Region, Read_Result);",
                    "               if Read_Result /= Profile.Read then",
                    "                  Status := Map_Read_Error (Read_Result);",
                    "                  return;",
                    "               end if;",
                    "               Profile.Initialize",
                    f"                 ({component}_Element_Reader,",
                    "                  Input,",
                    f"                  {component}_Element_Region,",
                    "                  Cursor_Result);",
                    "               if Cursor_Result /= Profile.Cursor_Ready then",
                    "                  Status := Flyology_Wire.Codecs.Malformed;",
                    "                  return;",
                    "               end if;",
                    "               "
                    + scalar_read_call(element, element_target, f"{component}_Element_Reader"),
                    "               if Read_Result /= Profile.Read",
                    f"                 or else not Profile.At_End ({component}_Element_Reader)",
                    "               then",
                    "                  Status := Map_Read_Error (Read_Result);",
                    "                  return;",
                    "               end if;",
                ]
            )
            invalid_element = scalar_invalid_expression(element, element_target)
            if invalid_element is not None:
                lines.extend(
                    [
                        f"               if {invalid_element} then",
                        "                  Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "                  return;",
                        "               end if;",
                    ]
                )
            if element_kind != "boolean":
                lines.append(f"               Element := Raw_{component}_Element;")
            lines.extend(
                [
                    f"               {component}_Remaining := {component}_Remaining - 1;",
                    "            end loop;",
                    f"            if {component}_Remaining /= 0 then",
                    "               Status := Flyology_Wire.Codecs.Invalid_Value;",
                    "               return;",
                    "            end if;",
                    "            if not Profile.At_End (Nested) then",
                    "               Status := Flyology_Wire.Codecs.Noncanonical;",
                    "               return;",
                    "            end if;",
                ]
            )
        if field["presence"] != "optional":
            lines.append(f"            Seen_{field['component']} := True;")
    ignored_by_tag: dict[int, list[int]] = {}
    for accepted_index, entry in enumerate(compatible, 1):
        for tag in entry["ignored"]:
            ignored_by_tag.setdefault(tag, []).append(accepted_index)
    for tag in sorted(ignored_by_tag):
        lines.append(f"         elsif Tag = Ignored_Writer_Tag_{tag}")
        accepted_indexes = ignored_by_tag[tag]
        lines.append(f"           and then (Writer = Accepted_Writer_{accepted_indexes[0]}_Schema")
        for accepted_index in accepted_indexes[1:]:
            lines.append(f"                     or else Writer = Accepted_Writer_{accepted_index}_Schema")
        lines[-1] += ")"
        lines.append("         then")
        for accepted_index in accepted_indexes:
            value = compatible[accepted_index - 1]["ignored"][tag]
            minimum = ada_integer(value["minimum_octets"])
            maximum = ada_integer(value["maximum_octets"])
            conditions = []
            if int(value["minimum_octets"]) > 0:
                conditions.append(f"Flyology_Wire.Byte_Count (Region.Length) < {minimum}")
            if int(value["maximum_octets"]) < schema_lock.U64_MAX:
                conditions.append(f"Flyology_Wire.Byte_Count (Region.Length) > {maximum}")
            lines.append(f"            if Writer = Accepted_Writer_{accepted_index}_Schema then")
            if conditions:
                append_condition(lines, conditions, 15)
                lines.extend(
                    [
                        "                  Status := Flyology_Wire.Codecs.Invalid_Value;",
                        "                  return;",
                        "               end if;",
                    ]
                )
            else:
                lines.append("               null;")
            lines.append("            end if;")
    lines.extend(
        [
            "         else",
            "            Status := Flyology_Wire.Codecs.Noncanonical;",
            "            return;",
            "         end if;",
            "      end loop;",
            "",
        ]
    )
    for field in fields:
        if field["default"] is None:
            continue
        lines.extend(
            [
                f"      if not Seen_{field['component']} then",
                f"         Candidate.{field['component']} := {field['default']};",
                f"         Seen_{field['component']} := True;",
                "      end if;",
                "",
            ]
        )
    for accepted_index, entry in enumerate(compatible, 1):
        for tag, literal in sorted(entry["construct"].items()):
            field = next(field for field in fields if field["schema"]["tag"] == tag)
            lines.extend(
                [
                    f"      if not Seen_{field['component']}",
                    f"        and then Writer = Accepted_Writer_{accepted_index}_Schema",
                    "      then",
                    f"         Candidate.{field['component']} := {literal};",
                    f"         Seen_{field['component']} := True;",
                    "      end if;",
                    "",
                ]
            )
    required = [field for field in fields if field["presence"] == "required"]
    if required:
        append_condition(lines, [f"not Seen_{field['component']}" for field in required], 6)
        lines.extend(
            [
                "         Status := Flyology_Wire.Codecs.Invalid_Value;",
                "      else",
                "         Item := Candidate;",
                "         Status := Flyology_Wire.Codecs.Decoded;",
                "      end if;",
            ]
        )
    else:
        lines.extend(
            [
                "      Item := Candidate;",
                "      Status := Flyology_Wire.Codecs.Decoded;",
            ]
        )
    lines.append("   end Decode;")
    if borrowed_observer_enabled(fields):
        append_borrowed_observer_body(lines, fields)
    lines.append(f"end {package_name};")
    return "\n".join(lines) + "\n"


def output_name(package_name: str, suffix: str) -> str:
    return package_name.lower().replace(".", "-") + suffix


def write_or_check(path: Path, content: str, check: bool) -> None:
    if check:
        try:
            existing = path.read_text(encoding="utf-8")
        except OSError as error:
            raise Generator_Error(f"{path}: {error}") from error
        if existing != content:
            raise Generator_Error(f"{path}: generated output is stale")
        return
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix(path.suffix + ".tmp")
    temporary.write_text(content, encoding="utf-8")
    temporary.replace(path)


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("schema", type=Path)
    parser.add_argument("binding", type=Path)
    parser.add_argument("output_directory", type=Path)
    parser.add_argument(
        "--compatible-writer",
        action="append",
        default=[],
        metavar=("WRITER_LOCK", "APPROVAL"),
        nargs=2,
        type=Path,
    )
    parser.add_argument("--check", action="store_true")
    args = parser.parse_args()
    try:
        schema = schema_lock.validate_lock(schema_lock.load(args.schema))
        binding = schema_lock.load(args.binding)
        fields = validate_binding(binding, schema)
        compatible = validate_compatible_writers(schema, fields, args.compatible_writer)
        if compatible and borrowed_observer_enabled(fields):
            raise Generator_Error(
                "$.fields: compatible-writer borrowed observers are not yet supported"
            )
        spec = render_spec(schema, binding, fields, compatible)
        body = render_body(schema, binding, fields, compatible)
        write_or_check(args.output_directory / output_name(binding["package_name"], ".ads"), spec, args.check)
        write_or_check(args.output_directory / output_name(binding["package_name"], ".adb"), body, args.check)
    except (OSError, schema_diff.Diff_Error, schema_lock.Lock_Error, Generator_Error) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
