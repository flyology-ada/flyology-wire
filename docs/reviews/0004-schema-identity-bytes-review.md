# Review 0004: Canonical schema identity bytes

Scope: the `Flyology_Wire.Identities.Schema_Identity` value, its canonical
56-byte encoding and validated decoding, codec ownership, and remoting-facing
interoperability.

Review date: 2026-08-23

## Findings and resolution

- P1: Keeping the aggregate schema identity only in `Codecs` left remoting
  without one authoritative value and canonical encoding for its envelope.
  `Schema_Identity` now belongs to `Identities`; `Codecs` retains a subtype so
  existing codec contracts use the same type without duplication.
- P1: Decoding the four fields independently could publish a partly valid
  identity. `Schema_Identity_From_Bytes` decodes into a local candidate and
  publishes it only after all four fields pass their sentinel checks.
- P2: The initial aggregate test checked field offsets but not the declared
  encoded length. The golden-layout assertion now also ties the output array
  length to `Schema_Identity_Length`.
- P2: Arithmetic on `Octet_Offset` was initially implicit and did not compile
  with the strict profile. The offsets are now explicit `Octet_Offset` values.

No P0, P1, or P2 finding remains open for this change.

## Verification after fixes

- The exact Flyology GNAT 16.2 Alire toolchain builds the library and nested
  test crate and the smoke test passes.
- A direct GNAT 15.3 compatibility build and smoke-test run pass with the same
  warning, validity-check, style, and overflow-checking switches.
- Golden tests cover field order, big-endian scalar fields, complete round trip,
  and each invalid-zero field independently.
- The public runtime source has no dependency on Flyology, remoting,
  Libadalang, or the shared Type IR.
