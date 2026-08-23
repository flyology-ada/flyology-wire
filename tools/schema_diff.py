#!/usr/bin/env python3
"""Produce and approve directional Flyology Wire schema-lock diffs."""

from __future__ import annotations

import argparse
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any

import schema_lock

DIFF_FORMAT = "flyology-wire-schema-diff"
APPROVAL_FORMAT = "flyology-wire-compatibility-approval"


class Diff_Error(ValueError):
    """A schema diff or approval failure."""


def canonical_json(value: Any) -> bytes:
    return json.dumps(value, ensure_ascii=True, separators=(",", ":"), sort_keys=True).encode("ascii")


def report_fingerprint(report: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_json(report)).hexdigest()


def issue(code: str, path: str) -> dict[str, str]:
    return {"code": code, "path": path}


def field_map(value: dict[str, Any]) -> dict[int, dict[str, Any]]:
    return {field["tag"]: field for field in value["fields"]}


def tagged_map(value: dict[str, Any], member: str) -> dict[int, dict[str, Any]]:
    return {item["tag"]: item for item in value[member]}


def require_subset(
    writer: int,
    reader: int,
    code: str,
    path: str,
    incompatibilities: list[dict[str, str]],
) -> None:
    if writer < reader:
        incompatibilities.append(issue(code, path))


def diff_value(
    writer: dict[str, Any],
    reader: dict[str, Any],
    path: str,
    requirements: list[dict[str, str]],
    incompatibilities: list[dict[str, str]],
) -> None:
    writer_kind = writer["kind"]
    reader_kind = reader["kind"]
    if writer_kind != reader_kind:
        incompatibilities.append(issue("kind_changed", path))
        return
    if writer_kind == "boolean":
        return
    if writer_kind in {"signed", "unsigned"}:
        require_subset(
            int(writer["minimum"]),
            int(reader["minimum"]),
            "writer_minimum_below_reader",
            path,
            incompatibilities,
        )
        require_subset(
            int(reader["maximum"]),
            int(writer["maximum"]),
            "writer_maximum_above_reader",
            path,
            incompatibilities,
        )
        return
    if writer_kind == "enumeration":
        writer_tags = set(tagged_map(writer, "values"))
        reader_tags = set(tagged_map(reader, "values"))
        for tag in sorted(writer_tags - reader_tags):
            incompatibilities.append(issue("writer_enum_tag_unknown_to_reader", f"{path}.value[{tag}]"))
        return
    if writer_kind in {"bytes", "text"}:
        require_count_subset(writer, reader, "octets", path, incompatibilities)
        if writer_kind == "text":
            if writer["encoding"] != reader["encoding"]:
                incompatibilities.append(issue("text_encoding_changed", path))
            require_count_subset(writer, reader, "scalars", path, incompatibilities)
        return
    if writer_kind == "record":
        diff_record(writer, reader, path, requirements, incompatibilities)
        return
    if writer_kind == "sequence":
        writer_dimensions = writer["dimensions"]
        reader_dimensions = reader["dimensions"]
        if len(writer_dimensions) != len(reader_dimensions):
            incompatibilities.append(issue("sequence_rank_changed", path))
            return
        for index, writer_dimension in enumerate(writer_dimensions):
            dimension_path = f"{path}.dimension[{index}]"
            require_count_subset(
                writer_dimension,
                reader_dimensions[index],
                "count",
                dimension_path,
                incompatibilities,
            )
        diff_value(writer["element"], reader["element"], f"{path}.element", requirements, incompatibilities)
        return
    if writer_kind == "optional":
        diff_value(writer["value"], reader["value"], f"{path}.value", requirements, incompatibilities)
        return
    if writer_kind == "variant":
        writer_alternatives = tagged_map(writer, "alternatives")
        reader_alternatives = tagged_map(reader, "alternatives")
        for tag in sorted(writer_alternatives):
            alternative_path = f"{path}.alternative[{tag}]"
            if tag not in reader_alternatives:
                incompatibilities.append(issue("writer_variant_tag_unknown_to_reader", alternative_path))
            else:
                diff_value(
                    writer_alternatives[tag]["value"],
                    reader_alternatives[tag]["value"],
                    alternative_path,
                    requirements,
                    incompatibilities,
                )


def require_count_subset(
    writer: dict[str, Any],
    reader: dict[str, Any],
    unit: str,
    path: str,
    incompatibilities: list[dict[str, str]],
) -> None:
    require_subset(
        int(writer[f"minimum_{unit}"]),
        int(reader[f"minimum_{unit}"]),
        f"writer_minimum_{unit}_below_reader",
        path,
        incompatibilities,
    )
    require_subset(
        int(reader[f"maximum_{unit}"]),
        int(writer[f"maximum_{unit}"]),
        f"writer_maximum_{unit}_above_reader",
        path,
        incompatibilities,
    )


def diff_record(
    writer: dict[str, Any],
    reader: dict[str, Any],
    path: str,
    requirements: list[dict[str, str]],
    incompatibilities: list[dict[str, str]],
) -> None:
    writer_fields = field_map(writer)
    reader_fields = field_map(reader)
    for tag in sorted(writer_fields):
        field_path = f"{path}.field[{tag}]"
        if tag not in reader_fields:
            requirements.append(issue("ignore_writer_field", field_path))
            continue
        writer_field = writer_fields[tag]
        reader_field = reader_fields[tag]
        if writer_field["presence"] != reader_field["presence"]:
            incompatibilities.append(issue("field_presence_changed", field_path))
            continue
        if (
            writer_field["presence"] == "defaulted"
            and writer_field["default_wire"] != reader_field["default_wire"]
        ):
            incompatibilities.append(issue("field_default_changed", field_path))
            continue
        diff_value(
            writer_field["value"],
            reader_field["value"],
            field_path,
            requirements,
            incompatibilities,
        )
    for tag in sorted(set(reader_fields) - set(writer_fields)):
        field = reader_fields[tag]
        if field["presence"] == "required":
            requirements.append(issue("construct_reader_field", f"{path}.field[{tag}]"))


def directional_diff(writer: dict[str, Any], reader: dict[str, Any]) -> dict[str, Any]:
    schema_lock.validate_lock(writer)
    schema_lock.validate_lock(reader)
    requirements: list[dict[str, str]] = []
    incompatibilities: list[dict[str, str]] = []
    if writer["family_id"] != reader["family_id"]:
        incompatibilities.append(issue("family_changed", "$"))
    if writer["profile_id"] != reader["profile_id"]:
        incompatibilities.append(issue("profile_changed", "$"))
    if not incompatibilities:
        diff_value(writer["root"], reader["root"], "$.root", requirements, incompatibilities)
    return {
        "diff_format": DIFF_FORMAT,
        "diff_version": 1,
        "incompatibilities": incompatibilities,
        "reader_fingerprint": reader["fingerprint"],
        "requirements": requirements,
        "writer_fingerprint": writer["fingerprint"],
    }


def evolution_issues(previous: dict[str, Any], current: dict[str, Any]) -> list[dict[str, str]]:
    schema_lock.validate_lock(previous)
    schema_lock.validate_lock(current)
    result: list[dict[str, str]] = []
    if previous["family_id"] != current["family_id"]:
        result.append(issue("family_changed", "$"))
    if previous["profile_id"] != current["profile_id"]:
        result.append(issue("profile_changed", "$"))
    if current["schema_revision"] <= previous["schema_revision"]:
        result.append(issue("revision_did_not_increase", "$"))
    if not result:
        evolve_value(previous["root"], current["root"], "$.root", result)
    return result


def evolve_tags(
    previous: dict[str, Any],
    current: dict[str, Any],
    member: str,
    path: str,
    result: list[dict[str, str]],
) -> None:
    previous_active = set(tagged_map(previous, member))
    current_active = set(tagged_map(current, member))
    previous_reserved = set(previous["reserved_tags"])
    current_reserved = set(current["reserved_tags"])
    for tag in sorted(previous_reserved - current_reserved):
        code = "reserved_tag_reused" if tag in current_active else "reserved_tag_forgotten"
        result.append(issue(code, f"{path}.tag[{tag}]"))
    for tag in sorted(previous_active - current_active - current_reserved):
        result.append(issue("removed_tag_not_reserved", f"{path}.tag[{tag}]"))


def evolve_value(
    previous: dict[str, Any],
    current: dict[str, Any],
    path: str,
    result: list[dict[str, str]],
) -> None:
    if previous["kind"] != current["kind"]:
        result.append(issue("value_kind_changed_within_family", path))
        return
    kind = previous["kind"]
    if kind == "record":
        evolve_tags(previous, current, "fields", path, result)
        previous_fields = field_map(previous)
        current_fields = field_map(current)
        for tag in sorted(set(previous_fields) & set(current_fields)):
            evolve_value(
                previous_fields[tag]["value"],
                current_fields[tag]["value"],
                f"{path}.field[{tag}]",
                result,
            )
    elif kind == "enumeration":
        evolve_tags(previous, current, "values", path, result)
    elif kind == "variant":
        evolve_tags(previous, current, "alternatives", path, result)
        previous_alternatives = tagged_map(previous, "alternatives")
        current_alternatives = tagged_map(current, "alternatives")
        for tag in sorted(set(previous_alternatives) & set(current_alternatives)):
            evolve_value(
                previous_alternatives[tag]["value"],
                current_alternatives[tag]["value"],
                f"{path}.alternative[{tag}]",
                result,
            )
    elif kind == "sequence":
        evolve_value(previous["element"], current["element"], f"{path}.element", result)
    elif kind == "optional":
        evolve_value(previous["value"], current["value"], f"{path}.value", result)


def resolve_path(reader: dict[str, Any], path: str) -> dict[str, Any]:
    value = reader["root"]
    if path == "$.root":
        return value
    position = len("$.root")
    token = re.compile(r"\.(?:(field|alternative)\[([0-9]+)\]|(element|value))")
    while position < len(path):
        match = token.match(path, position)
        if match is None:
            raise Diff_Error(f"{path}: has an invalid semantic path")
        kind, number, direct = match.groups()
        if direct is not None:
            if value.get("kind") == "sequence" and direct == "element":
                value = value["element"]
            elif value.get("kind") == "optional" and direct == "value":
                value = value["value"]
            else:
                raise Diff_Error(f"{path}: does not resolve in reader schema")
        else:
            member = "fields" if kind == "field" else "alternatives"
            selected = tagged_map(value, member).get(int(number))
            if selected is None:
                raise Diff_Error(f"{path}: does not resolve in reader schema")
            value = selected["value"]
        position = match.end()
    return value


def validate_approval(
    report: dict[str, Any],
    reader: dict[str, Any],
    approval: dict[str, Any],
) -> None:
    required_keys = {
        "approval_format",
        "approval_version",
        "diff_fingerprint",
        "reader_fingerprint",
        "resolutions",
        "writer_fingerprint",
    }
    if not isinstance(approval, dict) or set(approval) != required_keys:
        raise Diff_Error("approval has incorrect closed keys")
    if approval["approval_format"] != APPROVAL_FORMAT or approval["approval_version"] != 1:
        raise Diff_Error("approval format or version is unsupported")
    for member in ("reader_fingerprint", "writer_fingerprint"):
        if approval[member] != report[member]:
            raise Diff_Error(f"approval {member} does not match diff")
    if approval["diff_fingerprint"] != report_fingerprint(report):
        raise Diff_Error("approval diff_fingerprint does not match diff")
    if report["incompatibilities"]:
        raise Diff_Error("directional diff contains structural incompatibilities")
    resolutions = approval["resolutions"]
    if not isinstance(resolutions, list):
        raise Diff_Error("approval resolutions must be an array")
    if len(resolutions) != len(report["requirements"]):
        raise Diff_Error("approval resolutions do not exactly match ordered diff requirements")
    actual: list[dict[str, str]] = []
    for index, resolution in enumerate(resolutions):
        if not isinstance(resolution, dict) or "action" not in resolution or "path" not in resolution:
            raise Diff_Error("approval resolution must contain action and path")
        action = resolution["action"]
        path = resolution["path"]
        if issue(action, path) != report["requirements"][index]:
            raise Diff_Error("approval resolutions do not exactly match ordered diff requirements")
        if action == "ignore_writer_field" and set(resolution) == {"action", "path"}:
            actual.append(issue(action, path))
        elif action == "construct_reader_field" and set(resolution) == {"action", "default_wire", "path"}:
            encoded = schema_lock.require_ascii(resolution["default_wire"], f"{path}.default_wire")
            if schema_lock.LOWER_HEX.fullmatch(encoded) is None:
                schema_lock.fail(f"{path}.default_wire", "must be lowercase whole-octet hexadecimal")
            schema_lock.validate_encoded_value(resolve_path(reader, path), resolution["default_wire"], path)
            actual.append(issue(action, path))
        else:
            raise Diff_Error(f"unsupported or malformed resolution {action!r}")
    if actual != report["requirements"]:
        raise Diff_Error("approval resolutions do not exactly match ordered diff requirements")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("writer", type=Path)
    parser.add_argument("reader", type=Path)
    parser.add_argument("--approval", type=Path)
    parser.add_argument("--evolution", action="store_true")
    parser.add_argument("--fingerprint", action="store_true")
    args = parser.parse_args()
    try:
        writer = schema_lock.load(args.writer)
        reader = schema_lock.load(args.reader)
        if args.evolution:
            if args.approval is not None or args.fingerprint:
                parser.error("--evolution cannot be combined with approval or fingerprint output")
            problems = evolution_issues(writer, reader)
            if problems:
                raise Diff_Error(json.dumps(problems, ensure_ascii=True, sort_keys=True))
            return 0
        report = directional_diff(writer, reader)
        if args.approval is not None:
            validate_approval(report, reader, schema_lock.load(args.approval))
        if args.fingerprint:
            print(report_fingerprint(report))
        else:
            print(json.dumps(report, ensure_ascii=True, indent=2, sort_keys=True))
    except (schema_lock.Lock_Error, Diff_Error) as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
