# Review 0002: Writer schema on decode

Scope: decision 0002, `Schema_Identity`, the revised codec descriptor and
generic decode contract, and exact/incompatible handwritten-codec behavior.

Review date: 2026-08-23

## Findings and resolution

- P1: The initial decode contract lacked the writer schema, so an exact-schema
  parser could not apply a different unknown-field rule from a compatible
  writer-schema parser. `Decode` now receives a validated `Schema_Identity`.
- P2: The first correction tested a valid but unsupported fingerprint, but did
  not test an invalid zero-sentinel writer identity. The smoke test now covers
  both and verifies transactional failure.

No P0, P1, or P2 finding remains open for this decision.

## Verification after fixes

- The exact Flyology GNAT 16.2 Alire toolchain builds the library and nested
  test crate and the smoke test passes.
- The handwritten codec rejects invalid and unsupported writer identities
  before inspecting or publishing payload data.
- The dependency direction and opaque-envelope boundary are unchanged.
