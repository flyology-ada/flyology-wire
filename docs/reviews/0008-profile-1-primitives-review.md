# Review 0008: Canonical tagged Profile 1 primitives

Scope: accepted decision 0003, profile registry, unsigned and signed scalars,
booleans, field headers, ordered tags, nested extents, cursors, exact
measurement, golden vectors, and malformed-input behavior.

Review date: 2026-08-23

## Findings and resolution

- P1: The first child package name used reserved word `tagged`; the next name
  collided with the parent's `Canonical_Tagged` constant. The public unit is
  now the legal, unambiguous `Flyology_Wire.Profiles.Tagged_Profile`.
- P1: A cursor initialized against one array could be passed with a shorter
  array and index outside it. Every read and write entry point now validates
  the private cursor against the current array length before indexing and
  returns a status without consuming or modifying data.
- P1: A `Field_Tag` formal could reject zero through a subtype check before the
  promised `Invalid_Tag` status. Field-header writing now accepts `Tag_Number`,
  rejects the zero sentinel explicitly, and updates neither cursor nor prior
  tag on failure.
- P1: A parser that advanced through a malformed multi-octet scalar or header
  would make recovery and transactional generated decode unreliable. Reads use
  a local cursor and commit only after canonicality, range, order, and extent
  validation all succeed.
- P2: The initial tests did not exercise the maximum field tag, tenth-byte
  continuation, zero and out-of-range input tags, truncated lengths,
  decreasing output tags, or reuse with a smaller array. Golden and corruption
  coverage now includes each case.
- P2: A compile-time assertion for the fixed profile ID produced an
  always-true warning. The redundant assertion was removed; the constant is
  fixed by the public declaration and the accepted decision record.
- P2: GNAT 15 reported an unused visibility clause not reported in the first
  GNAT 16 build. The clause was removed before the compatibility rerun.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- GNATformat completed for every changed Ada source.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and both
  nested smoke programs; both pass.
- A direct GNAT 15.3 build and `tagged_smoke` run pass with strict warnings,
  validity checks, overflow checks, and the 110-column style limit.
- Golden vectors cover unsigned zero, 127/128, 300, unsigned maximum, both
  signed extremes, booleans, two ordered fields, and the maximum field tag.
- Failed primitive writes preserve output and cursor state. Failed primitive
  reads preserve cursor and previous-tag state.
- Runtime source remains pure, allocation-free, transport-independent, and
  free of Flyology, remoting, Libadalang, and Type IR dependencies.
