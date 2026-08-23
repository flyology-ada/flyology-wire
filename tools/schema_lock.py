#!/usr/bin/env python3
"""Validate and fingerprint Flyology Wire schema lock v1 files."""

from __future__ import annotations

import argparse
import copy
import hashlib
import json
import re
import sys
from pathlib import Path
from typing import Any, NoReturn

MAX_FIELD_TAG = 536_870_911
MAX_VALUE_TAG = 536_870_911
MAX_SCHEMA_DEPTH = 64
U32_MAX = 4_294_967_295
U64_MAX = 18_446_744_073_709_551_615
I64_MIN = -9_223_372_036_854_775_808
I64_MAX = 9_223_372_036_854_775_807
DECIMAL = re.compile(r"(?:0|-?[1-9][0-9]*)\Z")
NONNEGATIVE_DECIMAL = re.compile(r"(?:0|[1-9][0-9]*)\Z")
LOWER_HEX = re.compile(r"(?:[0-9a-f]{2})*\Z")


class Lock_Error(ValueError):
    """A closed-schema or canonicality failure."""


def fail(path: str, message: str) -> NoReturn:
    raise Lock_Error(f"{path}: {message}")


def pairs_object(pairs: list[tuple[str, Any]]) -> dict[str, Any]:
    result: dict[str, Any] = {}
    for key, value in pairs:
        if key in result:
            fail("$", f"duplicate object key {key!r}")
        result[key] = value
    return result


def require_object(value: Any, path: str, keys: set[str]) -> dict[str, Any]:
    if not isinstance(value, dict):
        fail(path, "must be an object")
    actual = set(value)
    if actual != keys:
        missing = sorted(keys - actual)
        extra = sorted(actual - keys)
        fail(path, f"closed keys differ; missing={missing}, extra={extra}")
    return value


def require_ascii(value: Any, path: str) -> str:
    if not isinstance(value, str):
        fail(path, "must be a string")
    try:
        value.encode("ascii")
    except UnicodeEncodeError:
        fail(path, "must contain only ASCII")
    return value


def require_decimal(value: Any, path: str, *, nonnegative: bool = False) -> int:
    text = require_ascii(value, path)
    pattern = NONNEGATIVE_DECIMAL if nonnegative else DECIMAL
    if pattern.fullmatch(text) is None:
        fail(path, "must be a normalized decimal string")
    if len(text.removeprefix("-")) > 20:
        fail(path, "exceeds the Profile 1 numeric domain")
    return int(text)


def require_construction_bound(value: Any, path: str) -> int:
    result = require_decimal(value, path)
    if not I64_MIN <= result <= I64_MAX:
        fail(path, "construction lower bound exceeds signed 64 bits")
    return result


def require_tag(value: Any, path: str, maximum: int) -> int:
    if isinstance(value, bool) or not isinstance(value, int) or not 1 <= value <= maximum:
        fail(path, f"must be an integer in 1 .. {maximum}")
    return value


def require_tag_order(items: list[Any], path: str, maximum: int) -> None:
    previous = 0
    for index, item in enumerate(items):
        if not isinstance(item, dict) or "tag" not in item:
            fail(f"{path}[{index}]", "must contain a tag")
        tag = require_tag(item["tag"], f"{path}[{index}].tag", maximum)
        if tag <= previous:
            fail(path, "tags must be strictly increasing")
        previous = tag


def require_reserved_tags(value: Any, path: str, maximum: int, active: set[int]) -> None:
    if not isinstance(value, list):
        fail(path, "must be an array")
    previous = 0
    for index, item in enumerate(value):
        tag = require_tag(item, f"{path}[{index}]", maximum)
        if tag <= previous:
            fail(path, "tags must be strictly increasing")
        if tag in active:
            fail(path, f"reserved tag {tag} is active")
        previous = tag


def varint_size(value: int) -> int:
    result = 1
    while value >= 0x80:
        value >>= 7
        result += 1
    return result


def checked_add(left: int, right: int, path: str) -> int:
    result = left + right
    if result > U64_MAX:
        fail(path, "maximum encoded size exceeds Byte_Count")
    return result


def checked_multiply(left: int, right: int, path: str) -> int:
    result = left * right
    if result > U64_MAX:
        fail(path, "maximum encoded size exceeds Byte_Count")
    return result


def maximum_size(value: dict[str, Any], path: str = "$.root") -> int:
    kind = value["kind"]
    if kind == "boolean":
        return 1
    if kind == "unsigned":
        return varint_size(int(value["maximum"]))
    if kind == "signed":
        minimum = int(value["minimum"])
        maximum = int(value["maximum"])

        def zigzag(item: int) -> int:
            return item * 2 if item >= 0 else -(item + 1) * 2 + 1

        return max(varint_size(zigzag(minimum)), varint_size(zigzag(maximum)))
    if kind == "enumeration":
        return max(varint_size(item["tag"]) for item in value["values"])
    if kind in {"bytes", "text"}:
        maximum = int(value["maximum_octets"])
        if maximum > U64_MAX:
            fail(f"{path}.maximum_octets", "exceeds Byte_Count")
        return maximum
    if kind == "record":
        result = 0
        for index, field in enumerate(value["fields"]):
            field_path = f"{path}.fields[{index}]"
            item_size = maximum_size(field["value"], f"{field_path}.value")
            result = checked_add(result, varint_size(field["tag"]), field_path)
            result = checked_add(result, varint_size(item_size), field_path)
            result = checked_add(result, item_size, field_path)
        return result
    if kind == "sequence":
        result = 0
        count = 1
        for index, dimension in enumerate(value["dimensions"]):
            dim_path = f"{path}.dimensions[{index}]"
            maximum = int(dimension["maximum_count"])
            if maximum > U64_MAX:
                fail(f"{dim_path}.maximum_count", "exceeds Byte_Count")
            result = checked_add(result, varint_size(maximum), dim_path)
            count = checked_multiply(count, maximum, dim_path)
        element_size = maximum_size(value["element"], f"{path}.element")
        framed_element = checked_add(varint_size(element_size), element_size, f"{path}.element")
        return checked_add(result, checked_multiply(count, framed_element, path), path)
    if kind == "optional":
        item_size = maximum_size(value["value"], f"{path}.value")
        return checked_add(1, checked_add(varint_size(item_size), item_size, path), path)
    if kind == "variant":
        result = 0
        for index, alternative in enumerate(value["alternatives"]):
            alt_path = f"{path}.alternatives[{index}]"
            item_size = maximum_size(alternative["value"], f"{alt_path}.value")
            framed = checked_add(varint_size(item_size), item_size, alt_path)
            framed = checked_add(varint_size(alternative["tag"]), framed, alt_path)
            result = max(result, framed)
        return result
    fail(f"{path}.kind", f"cannot measure unsupported kind {kind!r}")


def read_varint(data: bytes, position: int, limit: int, path: str) -> tuple[int, int]:
    result = 0
    for group in range(10):
        if position == limit:
            fail(path, "truncated varint")
        current = data[position]
        position += 1
        payload = current & 0x7F
        if group == 9 and payload > 1:
            fail(path, "varint exceeds 64 bits")
        result |= payload << (group * 7)
        if current & 0x80 == 0:
            if group > 0 and payload == 0:
                fail(path, "varint is not shortest-form")
            return result, position
    fail(path, "varint exceeds 64 bits")


def read_extent(data: bytes, position: int, limit: int, path: str) -> tuple[int, int]:
    length, position = read_varint(data, position, limit, f"{path}.length")
    end = position + length
    if end > limit:
        fail(path, "extent exceeds its container")
    return position, end


def validate_encoded_at(value: dict[str, Any], data: bytes, start: int, limit: int, path: str) -> None:
    kind = value["kind"]
    if kind == "boolean":
        if limit - start != 1 or data[start] not in (0, 1):
            fail(path, "Boolean must be exactly one zero or one octet")
        return
    if kind in {"signed", "unsigned", "enumeration"}:
        encoded, position = read_varint(data, start, limit, path)
        if position != limit:
            fail(path, "scalar has trailing octets")
        if kind == "unsigned":
            decoded = encoded
            if not int(value["minimum"]) <= decoded <= int(value["maximum"]):
                fail(path, "unsigned value is outside its declared range")
        elif kind == "signed":
            magnitude = encoded // 2
            decoded = magnitude if encoded % 2 == 0 else -magnitude - 1
            if not int(value["minimum"]) <= decoded <= int(value["maximum"]):
                fail(path, "signed value is outside its declared range")
        elif encoded not in {item["tag"] for item in value["values"]}:
            fail(path, "enumeration tag is not declared")
        return
    if kind == "bytes":
        length = limit - start
        if not int(value["minimum_octets"]) <= length <= int(value["maximum_octets"]):
            fail(path, "byte value is outside its octet bounds")
        return
    if kind == "text":
        length = limit - start
        if not int(value["minimum_octets"]) <= length <= int(value["maximum_octets"]):
            fail(path, "text value is outside its octet bounds")
        try:
            decoded = data[start:limit].decode("utf-8", errors="strict")
        except UnicodeDecodeError as error:
            fail(path, f"text is not canonical UTF-8: {error.reason}")
        if not int(value["minimum_scalars"]) <= len(decoded) <= int(value["maximum_scalars"]):
            fail(path, "text value is outside its scalar bounds")
        return
    if kind == "record":
        fields = {field["tag"]: field for field in value["fields"]}
        seen: set[int] = set()
        previous = 0
        position = start
        while position < limit:
            tag, position = read_varint(data, position, limit, f"{path}.tag")
            if not 1 <= tag <= MAX_FIELD_TAG or tag <= previous:
                fail(path, "record tags must be valid and strictly increasing")
            previous = tag
            payload_start, payload_end = read_extent(data, position, limit, f"{path}.field[{tag}]")
            position = payload_end
            field = fields.get(tag)
            if field is None:
                fail(path, f"record contains unknown tag {tag}")
            validate_encoded_at(field["value"], data, payload_start, payload_end, f"{path}.field[{tag}]")
            if (
                field["presence"] == "defaulted"
                and data[payload_start:payload_end].hex() == field["default_wire"]
            ):
                fail(path, f"defaulted field {tag} explicitly encodes its default")
            seen.add(tag)
        for tag, field in fields.items():
            if field["presence"] == "required" and tag not in seen:
                fail(path, f"record omits required tag {tag}")
        return
    if kind == "sequence":
        position = start
        count = 1
        for index, dimension in enumerate(value["dimensions"]):
            current, position = read_varint(data, position, limit, f"{path}.dimension[{index}]")
            if not int(dimension["minimum_count"]) <= current <= int(dimension["maximum_count"]):
                fail(path, f"dimension {index} is outside its count bounds")
            count = checked_multiply(count, current, path)
        if count > limit - position:
            fail(path, "element count cannot fit in the remaining extent")
        for index in range(count):
            element_start, element_end = read_extent(data, position, limit, f"{path}.element[{index}]")
            position = element_end
            validate_encoded_at(
                value["element"], data, element_start, element_end, f"{path}.element[{index}]"
            )
        if position != limit:
            fail(path, "sequence has trailing octets")
        return
    if kind == "optional":
        if start == limit or data[start] not in (0, 1):
            fail(path, "optional presence must be exactly zero or one")
        if data[start] == 0:
            if start + 1 != limit:
                fail(path, "absent optional has trailing octets")
            return
        payload_start, payload_end = read_extent(data, start + 1, limit, path)
        if payload_end != limit:
            fail(path, "present optional has trailing octets")
        validate_encoded_at(value["value"], data, payload_start, payload_end, f"{path}.value")
        return
    if kind == "variant":
        tag, position = read_varint(data, start, limit, f"{path}.tag")
        alternatives = {alternative["tag"]: alternative for alternative in value["alternatives"]}
        if tag not in alternatives:
            fail(path, f"variant tag {tag} is not declared")
        payload_start, payload_end = read_extent(data, position, limit, path)
        if payload_end != limit:
            fail(path, "variant has trailing octets")
        validate_encoded_at(alternatives[tag]["value"], data, payload_start, payload_end, f"{path}.value")
        return
    fail(f"{path}.kind", f"cannot validate unsupported kind {kind!r}")


def validate_encoded_value(value: dict[str, Any], encoded: str, path: str) -> None:
    data = bytes.fromhex(encoded)
    validate_encoded_at(value, data, 0, len(data), path)


def validate_value(value: Any, path: str, depth: int = 0) -> None:
    if depth > MAX_SCHEMA_DEPTH:
        fail(path, f"schema nesting exceeds {MAX_SCHEMA_DEPTH}")
    if not isinstance(value, dict):
        fail(path, "must be an object")
    kind = require_ascii(value.get("kind"), f"{path}.kind")
    if kind == "boolean":
        require_object(value, path, {"kind"})
    elif kind in {"signed", "unsigned"}:
        item = require_object(value, path, {"kind", "maximum", "minimum"})
        minimum = require_decimal(item["minimum"], f"{path}.minimum")
        maximum = require_decimal(item["maximum"], f"{path}.maximum")
        if minimum > maximum:
            fail(path, "minimum exceeds maximum")
        if kind == "unsigned" and minimum < 0:
            fail(path, "unsigned minimum must be nonnegative")
        if kind == "unsigned" and maximum > 2**64 - 1:
            fail(path, "unsigned Profile 1 maximum exceeds 64 bits")
        if kind == "signed" and (minimum < -(2**63) or maximum > 2**63 - 1):
            fail(path, "signed Profile 1 range exceeds 64 bits")
    elif kind == "enumeration":
        item = require_object(value, path, {"kind", "reserved_tags", "values"})
        values = item["values"]
        if not isinstance(values, list) or not values:
            fail(f"{path}.values", "must be a nonempty array")
        require_tag_order(values, f"{path}.values", MAX_VALUE_TAG)
        for index, enum_value in enumerate(values):
            require_object(enum_value, f"{path}.values[{index}]", {"tag"})
        require_reserved_tags(
            item["reserved_tags"],
            f"{path}.reserved_tags",
            MAX_VALUE_TAG,
            {enum_value["tag"] for enum_value in values},
        )
    elif kind in {"bytes", "text"}:
        keys = {"construction_lower_bound", "kind", "maximum_octets", "minimum_octets"}
        if kind == "text":
            keys.update({"encoding", "maximum_scalars", "minimum_scalars"})
        item = require_object(value, path, keys)
        require_construction_bound(item["construction_lower_bound"], f"{path}.construction_lower_bound")
        minimum = require_decimal(item["minimum_octets"], f"{path}.minimum_octets", nonnegative=True)
        maximum = require_decimal(item["maximum_octets"], f"{path}.maximum_octets", nonnegative=True)
        if minimum > maximum:
            fail(path, "minimum octet count exceeds maximum")
        if kind == "text":
            minimum_scalars = require_decimal(
                item["minimum_scalars"], f"{path}.minimum_scalars", nonnegative=True
            )
            maximum_scalars = require_decimal(
                item["maximum_scalars"], f"{path}.maximum_scalars", nonnegative=True
            )
            if minimum_scalars > maximum_scalars:
                fail(path, "minimum scalar count exceeds maximum")
            if minimum > maximum_scalars * 4 or minimum_scalars > maximum:
                fail(path, "text octet and scalar bounds admit no value")
            if item["encoding"] != "utf-8":
                fail(f"{path}.encoding", "must be 'utf-8'")
    elif kind == "record":
        item = require_object(value, path, {"fields", "kind", "reserved_tags"})
        fields = item["fields"]
        if not isinstance(fields, list):
            fail(f"{path}.fields", "must be an array")
        require_tag_order(fields, f"{path}.fields", MAX_FIELD_TAG)
        for index, field in enumerate(fields):
            field_path = f"{path}.fields[{index}]"
            if not isinstance(field, dict):
                fail(field_path, "must be an object")
            presence = field.get("presence")
            keys = {"presence", "tag", "value"}
            if presence == "defaulted":
                keys.add("default_wire")
            elif presence not in {"optional", "required"}:
                fail(f"{field_path}.presence", "must be defaulted, optional, or required")
            field = require_object(field, field_path, keys)
            require_tag(field["tag"], f"{field_path}.tag", MAX_FIELD_TAG)
            if presence == "defaulted":
                encoded = require_ascii(field["default_wire"], f"{field_path}.default_wire")
                if LOWER_HEX.fullmatch(encoded) is None:
                    fail(f"{field_path}.default_wire", "must be lowercase whole-octet hexadecimal")
            validate_value(field["value"], f"{field_path}.value", depth + 1)
            if presence == "defaulted":
                validate_encoded_value(field["value"], encoded, f"{field_path}.default_wire")
        require_reserved_tags(
            item["reserved_tags"],
            f"{path}.reserved_tags",
            MAX_FIELD_TAG,
            {field["tag"] for field in fields},
        )
    elif kind == "sequence":
        item = require_object(value, path, {"dimensions", "element", "kind"})
        dimensions = item["dimensions"]
        if not isinstance(dimensions, list) or not dimensions:
            fail(f"{path}.dimensions", "must be a nonempty array")
        for index, dimension in enumerate(dimensions):
            dim_path = f"{path}.dimensions[{index}]"
            dimension = require_object(
                dimension,
                dim_path,
                {"construction_lower_bound", "maximum_count", "minimum_count"},
            )
            require_construction_bound(
                dimension["construction_lower_bound"], f"{dim_path}.construction_lower_bound"
            )
            minimum = require_decimal(
                dimension["minimum_count"], f"{dim_path}.minimum_count", nonnegative=True
            )
            maximum = require_decimal(
                dimension["maximum_count"], f"{dim_path}.maximum_count", nonnegative=True
            )
            if minimum > maximum:
                fail(dim_path, "minimum count exceeds maximum")
        validate_value(item["element"], f"{path}.element", depth + 1)
    elif kind == "optional":
        item = require_object(value, path, {"kind", "value"})
        validate_value(item["value"], f"{path}.value", depth + 1)
    elif kind == "variant":
        item = require_object(value, path, {"alternatives", "kind", "reserved_tags"})
        alternatives = item["alternatives"]
        if not isinstance(alternatives, list) or not alternatives:
            fail(f"{path}.alternatives", "must be a nonempty array")
        require_tag_order(alternatives, f"{path}.alternatives", MAX_VALUE_TAG)
        for index, alternative in enumerate(alternatives):
            alt_path = f"{path}.alternatives[{index}]"
            alternative = require_object(alternative, alt_path, {"tag", "value"})
            require_tag(alternative["tag"], f"{alt_path}.tag", MAX_VALUE_TAG)
            validate_value(alternative["value"], f"{alt_path}.value", depth + 1)
            if alternative["value"].get("kind") != "record":
                fail(f"{alt_path}.value", "variant payload must be a record")
        require_reserved_tags(
            item["reserved_tags"],
            f"{path}.reserved_tags",
            MAX_VALUE_TAG,
            {alternative["tag"] for alternative in alternatives},
        )
    else:
        fail(f"{path}.kind", f"unsupported Profile 1 kind {kind!r}")


def validate_lock(document: Any, *, verify_fingerprint: bool = True) -> dict[str, Any]:
    item = require_object(
        document,
        "$",
        {
            "family_id",
            "fingerprint",
            "lock_format",
            "lock_version",
            "profile_id",
            "root",
            "schema_revision",
        },
    )
    if item["lock_format"] != "flyology-wire-schema-lock":
        fail("$.lock_format", "has an unsupported value")
    if type(item["lock_version"]) is not int or item["lock_version"] != 1:
        fail("$.lock_version", "must be integer 1")
    if type(item["profile_id"]) is not int or item["profile_id"] != 1:
        fail("$.profile_id", "must be integer 1")
    revision = item["schema_revision"]
    if isinstance(revision, bool) or not isinstance(revision, int) or not 1 <= revision <= U32_MAX:
        fail("$.schema_revision", f"must be an integer in 1 .. {U32_MAX}")
    family = require_ascii(item["family_id"], "$.family_id")
    if len(family) != 32 or LOWER_HEX.fullmatch(family) is None or family == "0" * 32:
        fail("$.family_id", "must be 16 nonzero lowercase hexadecimal octets")
    fingerprint = require_ascii(item["fingerprint"], "$.fingerprint")
    if len(fingerprint) != 64 or LOWER_HEX.fullmatch(fingerprint) is None or fingerprint == "0" * 64:
        fail("$.fingerprint", "must be 32 nonzero lowercase hexadecimal octets")
    validate_value(item["root"], "$.root")
    maximum_size(item["root"])
    if verify_fingerprint:
        expected = schema_fingerprint(item)
        if fingerprint != expected:
            fail("$.fingerprint", f"expected {expected}")
    return item


def canonical_projection(document: dict[str, Any]) -> bytes:
    projection = copy.deepcopy(document)
    projection.pop("fingerprint", None)
    return json.dumps(projection, ensure_ascii=True, separators=(",", ":"), sort_keys=True).encode("ascii")


def schema_fingerprint(document: dict[str, Any]) -> str:
    return hashlib.sha256(canonical_projection(document)).hexdigest()


def load(path: Path) -> Any:
    def invalid_constant(value: str) -> NoReturn:
        fail("$", f"non-JSON numeric constant {value!r}")

    try:
        return json.loads(
            path.read_text(encoding="utf-8"),
            object_pairs_hook=pairs_object,
            parse_constant=invalid_constant,
        )
    except (OSError, RecursionError, UnicodeError, json.JSONDecodeError) as error:
        raise Lock_Error(f"{path}: {error}") from error


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("path", type=Path)
    parser.add_argument("--fingerprint", action="store_true", help="print the computed fingerprint")
    parser.add_argument("--projection", action="store_true", help="write canonical fingerprint bytes")
    parser.add_argument("--maximum-size", action="store_true", help="print the static maximum encoded size")
    parser.add_argument(
        "--set-fingerprint", action="store_true", help="print a validated lock with its fingerprint set"
    )
    args = parser.parse_args()
    if sum((args.fingerprint, args.maximum_size, args.projection, args.set_fingerprint)) > 1:
        parser.error("select at most one output mode")
    try:
        document = load(args.path)
        if args.set_fingerprint and isinstance(document, dict):
            if document.get("fingerprint") in (None, "0" * 64):
                document["fingerprint"] = "1" * 64
        validate_lock(document, verify_fingerprint=not args.set_fingerprint)
        if args.fingerprint:
            print(schema_fingerprint(document))
        elif args.maximum_size:
            print(maximum_size(document["root"]))
        elif args.projection:
            sys.stdout.buffer.write(canonical_projection(document))
        elif args.set_fingerprint:
            document["fingerprint"] = schema_fingerprint(document)
            print(json.dumps(document, ensure_ascii=True, indent=2, sort_keys=True))
    except Lock_Error as error:
        print(error, file=sys.stderr)
        return 1
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
