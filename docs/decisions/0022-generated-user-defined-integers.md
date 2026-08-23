# Decision 0022: Generated integer bindings use explicit exact-range conversions

Status: accepted initial milestone

Date: 2026-08-23

## Context

The initial Ada generator bound signed and unsigned wire scalars only to
`Interfaces.Integer_64` and `Interfaces.Unsigned_64`. Ordinary Ada source more
often declares a named range or modular type. Treating the physical
representation of that type as the wire representation would couple Profile 1
to compiler layout, while assigning a decoded 64-bit value directly does not
type-check and can bypass the application's declared range.

## Decision

A scalar binding may name an expanded Ada integer type explicitly with the
closed form `{ "kind": "integer_type", "type_name": "Unit.Type" }`. Boolean
bindings remain exact and do not accept this form.

This binding is eligible only when the structural adapter proves that the
named type and the record component have one static contiguous scalar range,
no predicate, and the same minimum and maximum as the wire scalar. The reviewed
Type IR adapter owns that proof. Before that adapter emits this form, a manually
authored binding is a reviewed type-adapter assertion, not inferred schema.

Generated Ada reinforces the assertion at compile time. A
`Compile_Time_Error` rejects a named application type whose range differs from
the wire range, and generated record aggregates assign both wire endpoints
through the named type. Those aggregates reject a component subtype that
cannot represent the complete wire range.

Measure and Encode convert application values explicitly to the corresponding
64-bit Profile 1 primitive after those checks. Decode validates the raw 64-bit
value against the wire schema, converts it explicitly to the named type, and
assigns only an unpublished candidate. Canonical bytes and schema identity do
not include the Ada type name.

The first borrowed observer still exposes exact Profile 1 scalar types.
Combining it with a converted application scalar is rejected until an
application-typed callback contract is separately reviewed.

## Consequences

- Named signed, modular, and integer-derived application fields can use the
  canonical Profile 1 integer encoding without layout coupling.
- Wider, narrower, predicate-bearing, nonstatic, or otherwise imprecise source
  types fail in the Type IR adapter; the generated Ada build independently
  catches range drift in accepted bindings.
- Supporting a wire range that is a proper subset of an application type
  remains a later decision because it needs a deliberately validated runtime
  domain rather than an exact structural binding.
- Arrays, variant members, optional/defaulted converted scalars, and borrowed
  application-typed views remain later reviewed extensions.
