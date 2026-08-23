# Review 0025: Profile 1 value-tag domain

Scope: decision 0019; field, enumeration, and variant active/reserved tag
ranges; canonical varint width; schema validation; and evolution consequences.

Review date: 2026-08-23

## Findings and resolution

- P1: The accepted profile text constrained field tags but described enum and
  variant tags only as nonzero, leaving two wire grammars possible. Decision
  0019 and decision 0003 now fix all three tag kinds at
  `1 .. 2**29 - 1`.
- P1: Conflating tag bounds with length or scalar bounds would incorrectly
  limit payload sizes and integer values. The decision preserves the existing
  unsigned 64-bit domains for lengths, counts, and ordinary scalar encodings.
- P1: Ada enumeration position or representation could accidentally become a
  wire identity. Generator bindings require a complete explicit literal/tag
  map, and the enum fixture uses representation values different from its wire
  tags.
- P2: Equal numeric ranges could obscure the distinct evolution roles of field
  and value tags. JSON Schema and the executable validator retain separate
  `field_tag` and `value_tag` definitions/constants.
- P2: A future silent widening would change what existing decoders reject.
  Decision 0019 makes widening a new reviewed profile decision rather than a
  schema-only evolution.

## Verification

- JSON Schema bounds both tag definitions at `536870911`.
- Executable schema tests accept `536870911` for enum and variant tags and
  reject `536870912` for each.
- The generated enumeration smoke maps Ada representation values 42 and 99 to
  explicit wire tags 1 and 9 and rejects undeclared tag 2.
- The full schema, diff, generator, rejection, and Ada smoke suite passes with
  warnings promoted to errors under the pinned GNAT 16.2 toolchain.

No open P0, P1, or P2 finding remains in the value-tag-domain decision.
