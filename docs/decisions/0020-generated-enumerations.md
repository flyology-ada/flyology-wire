# Decision 0020: Generated enumerations use complete explicit literal maps

Status: accepted initial milestone

Date: 2026-08-23

## Context

An Ada enumeration declaration supplies literal order and may supply machine
representation values, but neither is a durable wire contract. Profile 1
instead assigns stable value tags in the wire overlay. The generator needs a
closed binding from those semantic tags to the application type without
depending on compiler layout or source order.

## Decision

The initial enumeration binding is available for a required record field. It
names the Ada component and supplies one expanded Ada literal name for every
active schema value tag, in schema tag order. Missing, duplicate, reordered, or
extra mappings fail generation. Tags are constrained by decision 0019.

Generated Measure validates the Ada component and measures the shortest varint
of the explicitly mapped tag. Encode selects that same tag with a generated Ada
case statement. Decode accepts only an active schema tag and assigns its mapped
literal to an unpublished candidate; an undeclared or retired tag returns
`Invalid_Value`. Nonminimal varints remain `Noncanonical`.

Generated compile-time aggregates mention every mapped literal in the bound
record type. This makes a stale or misspelled binding fail the Ada build even
if a particular literal is not used by a test. The first schema-tag literal is
the deterministic failure value published when decode does not succeed.

This slice deliberately does not infer names or tags from Type IR. The future
adapter will resolve the enumeration declaration and validate the overlay, then
emit the same closed schema-lock/binding input at the existing generator seam.

## Consequences

- Reordering Ada literals or changing an enumeration representation clause
  does not change canonical bytes when the explicit binding remains valid.
- Adding a schema literal requires a corresponding reviewed wire tag and Ada
  binding; generator omission cannot silently select an ordinal.
- Enumeration aliases, open/unknown-value application representations, and
  optional/defaulted enumeration fields remain later reviewed extensions.
