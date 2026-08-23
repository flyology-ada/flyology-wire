# Review 0012: End-to-end Profile 1 codec pattern

Scope: decisions 0002, 0003, 0004, and 0006; exact measurement, bounded
encoding, transactionality, canonical decoding, and directional schema
evolution in a statically bound handwritten codec.

Review date: 2026-08-23

## Findings and resolution

- P1: The initial top-level writer covered the caller's full destination, so
  its final `At_End` check failed whenever the destination had unused capacity
  and could not prove that encoding filled the exact measured extent. Encoding
  now constrains the top-level writer to the measured prefix before any write.
- P1: Nested cursor initialization failure was combined with a mapping of the
  previous scalar read status. Although validated field extents make that
  branch unreachable, the code could report a stale classification if the
  invariant changed. Cursor failure now maps directly to `Malformed` before a
  nested read.
- P2: The first smoke test covered successful evolution but too few complete
  codec corruption paths. Coverage now includes duplicate tags, trailing field
  bytes, truncated and overlong varints, an extent outside the payload, an
  invalid Boolean, an application-invalid scalar, an unapproved future tag,
  and a future writer missing a required field.
- P2: The declared static maximum was not tied to an executable exact-measure
  case. The maximum 64-bit value now measures to the descriptor's 15-byte
  ceiling in the smoke test.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- GNATformat completed for the codec specification, body, and smoke program.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and all four
  smoke programs; all pass.
- A direct GNAT 15.3 build and `profile_codec_smoke` run pass with strict
  warnings, validity checks, overflow checks, and the 110-column style limit.
- Failed measurement or destination preflight returns before the first write;
  tests prove insufficient and application-invalid encodes leave caller
  storage unchanged and publish zero bytes.
- Decode initializes a harmless destination, constructs a local candidate,
  and commits only after schema-specific canonical and application validation.
  Every tested failure retains the harmless destination.
- Exact schema rejects unknown tags. Only the explicit future writer edge may
  skip tag 3; an arbitrary tag remains noncanonical. The older edge applies
  its explicit construction default and rejects fields absent from that writer
  schema.
- The codec uses only the pure wire runtime, stack values, and caller arrays;
  it introduces no access types, allocation, transport, remoting, Type IR,
  Libadalang, or serde dependency.
