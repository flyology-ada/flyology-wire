# Review 0005: Checked size arithmetic

Scope: decision 0004, `Flyology_Wire.Sizes`, generated-code usage rules,
overflow behavior, and arithmetic boundary tests.

Review date: 2026-08-23

## Findings and resolution

- P1: `Byte_Count` is modular, so unchecked arithmetic would silently wrap
  even when compiler overflow checks are enabled. Addition now compares before
  subtracting from the maximum, and multiplication divides the maximum only
  after excluding a zero divisor.
- P1: A failed incremental measurement could corrupt a previously valid total.
  `Accumulate` computes into a local candidate and changes the total only on
  success.
- P2: Initial tests covered overflow and zero multiplication but omitted exact
  maximum multiplication and successful accumulation. Both boundary cases are
  now covered.

No P0, P1, or P2 finding remains open for this change.

## Verification after fixes

- GNATformat completed for the new package and changed test source.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and nested
  test crate and the smoke test passes.
- A direct GNAT 15.3 compatibility build and smoke-test run pass with strict
  warnings, validity checks, overflow checks, and the 110-column style limit.
- The package is pure, allocation-free, and independent of the payload profile,
  remoting, Flyology, Libadalang, and the shared Type IR.
