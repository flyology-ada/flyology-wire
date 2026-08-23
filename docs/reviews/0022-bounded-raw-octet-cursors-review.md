# Review 0022: Bounded raw octet cursor copies

Scope: decision 0016, raw read/write cursor behavior, arbitrary array bounds,
failure atomicity, zero-length operation, status classification, and generated
byte-field prerequisites.

Review date: 2026-08-23

## Findings and resolution

- P1: Copying before checking both arrays could partially publish malformed
  input or partially alter an encode destination. Both procedures preflight
  the complete count before the first assignment and advance the cursor only
  after the complete loop.
- P1: A normal Ada array conversion between distinct array types could create
  a copy and defeat Flyology buffer interoperability. The API uses the root
  `Octet_Array` subtype, which is compatible with
  `Ada.Streams.Stream_Element_Array`, and performs no conversion or overlay.
- P1: A zero count expressed as `0 .. Count - 1` could underflow before the
  loop is reached. The loop exists only inside an explicit `Count > 0` guard.
- P2: Tests with only one-based arrays would miss lower-bound arithmetic
  defects. The smoke fixture copies between arrays whose first indexes are 40,
  50, and 60.
- P2: One generic insufficient-space status on read would obscure whether the
  payload ended or the application binding was too small. Read status now
  distinguishes `Truncated` from `Destination_Too_Small`; generated code is
  still required to preflight the latter.

## Verification

- `tagged_smoke` covers nonempty and zero-length operations, arbitrary lower
  bounds, short wire input, short application input/output, unchanged storage,
  and unchanged cursor positions on every failure path.
- The complete 22 schema tests, 8 directional-diff tests, 10 generator tests,
  expected binding-rejection builds, and all 10 Ada smoke executables pass
  under the pinned GNAT 16.2 toolchain with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this cursor-primitive slice.
