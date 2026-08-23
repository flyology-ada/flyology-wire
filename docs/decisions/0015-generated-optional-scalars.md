# Decision 0015: Generated optional scalars use an explicit presence component

Status: accepted initial milestone

Date: 2026-08-23

## Context

An optional record field must distinguish absence from a present scalar whose
value happens to equal an application or wire default. A plain Ada scalar
component cannot represent that distinction, and inferring presence from its
value would collapse `some(default)` into none.

## Decision

The initial scalar backend accepts an `optional` field only when its closed Ada
binding names both:

- one Boolean presence component; and
- one Boolean, `Interfaces.Integer_64`, or `Interfaces.Unsigned_64` value
  component.

`Present = False` means none and makes the value component semantically
unobserved. Generated measure and encode do not validate or encode that hidden
value. `Present = True` validates the scalar and emits the ordinary tagged
field, including when the scalar is zero, false, or another default-looking
value.

Generated decode initializes the presence component to false and the hidden
value to its schema lower value. A canonically present field decodes into the
candidate and sets presence true. Absence needs no required-field or default
construction action. The candidate remains unpublished until the complete root
payload has passed all other checks.

An all-optional record may therefore encode as a zero-byte payload inside its
outer frame. This uses the same zero-extent writer path as an all-defaulted
record, but the reconstructed semantics differ: optional absence preserves
none, while defaulted absence constructs a value.

## Consequences

- Optionality remains explicit application state rather than an inferred Ada
  convention or serde capability.
- Hidden storage can contain any scalar bit-pattern/value allowed by its Ada
  type without making none invalid; applications should not include hidden
  storage in logical equality unless they normalize it.
- The compiler legality gate proves the named presence component accepts
  Boolean assignments and the value component accepts the exact scalar path.
- Optional bounded sequences and nested optionals require additional definite
  builder bindings and are not implied by this scalar slice.
