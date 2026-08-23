# Review 0010: Directional compatibility runtime

Scope: decision 0006, accepted-writer table validity, classification,
directionality, family/profile boundaries, array bounds, and failure behavior.

Review date: 2026-08-23

## Findings and resolution

- P1: A caller could classify against a malformed handwritten table without
  first calling the separate validator, allowing a listed identity despite
  duplicate or cross-boundary configuration. `Classify` now validates the table
  and returns `Invalid_Table` before exact or compatible acceptance.
- P1: Duplicate detection computed `Index - 1`; a zero-based array would raise
  on its first element before forming a null range. The earlier-range loop is
  now entered only when the current index differs from the array's first.
- P2: Initial tests used only one-based and null arrays. Coverage now includes
  a zero-based table, fail-closed classification of a duplicate table, and an
  explicit reverse-direction rejection.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- GNATformat completed for the new package and test source.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and all three
  smoke programs; all pass.
- A direct GNAT 15.3 build and `compatibility_smoke` run pass with strict
  warnings, validity checks, overflow checks, and the 110-column style limit.
- Tests cover valid older/newer writers, exact identity, empty/one-/zero-based
  tables, duplicates, local entries, invalid identities, foreign families,
  foreign profiles, unlisted writers, and directional reversal.
- The package is pure and allocation-free; proof of compatibility and
  writer-specific unknown-tag rules remain offline/generated responsibilities.
