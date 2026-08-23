# Review 0023: Generated bounded bytes and scoped observers

Scope: decision 0017, closed bytes binding, exact measure/encode, transactional
construction, static Ada geometry checks, two-pass observation, payload
address preservation, and callback/error behavior.

Review date: 2026-08-23

## Findings and resolution

- P1: Accepting an arbitrary Ada byte-array spelling could allow a conversion
  copy or unsafe address overlay. The binding selects only the
  stream-element-array path, and generated calls pass the application component
  directly to `Read_Octets`/`Write_Octets`; Ada compilation checks actual type
  compatibility.
- P1: A logical length larger than schema capacity or the bound Ada array could
  raise during conversion or partially modify output. Measure validates both
  bounds before any `Byte_Count`/`Octet_Count` conversion, and Encode invokes
  Measure before initializing its writer.
- P1: Direct decode into the published item would expose a byte prefix when a
  later field fails. Decode modifies only a fully initialized local candidate
  and assigns the `out` item after all required fields pass.
- P1: Invoking callbacks while validating would expose a logical prefix from a
  payload later found malformed. Generated observation performs a complete
  callback-free first pass, then reparses under the documented stable-input
  contract.
- P1: Returning a slice, access value, or address-bearing wrapper would allow a
  view to outlive remoting's payload lease. Byte observation exists only as a
  generic callback instantiated through `Visit_Extent`.
- P1: Reusing the exact-schema visitor for approved compatibility edges would
  skip writer-specific construction and ignored-tag policy. The generator
  rejects that combination until it has a reviewed visitor lowering.
- P2: A one-based fixture would not prove construction-bound arithmetic or
  direct buffer compatibility. The generated fixture uses a wire-octet subtype
  indexed `3 .. 6`, and separate expected-failure projects prove capacity and
  lower-bound diagnostics.
- P2: Empty bytes could be confused with optional absence. The smoke test proves
  that a required empty byte value emits a zero-length field and that its
  observer receives a safe zero-length slice.

## Verification

- The committed bytes lock has fingerprint
  `f84e3a0454ad0c6ee4055ba9c16bf537f89d7cf0b3fc593d739ce33169d923ac`
  and a static maximum of ten octets.
- Eleven generator tests cover deterministic and line-bounded output, closed
  byte keys, exact array-mode selection, Boolean observer opt-in, raw cursor
  calls, and generated visitor structure.
- `generated_bytes_codec_smoke` proves exact measure, canonical bytes, empty
  required bytes, invalid-length nonmutation, normalized unused capacity,
  transactional failure, whole-payload validation before callbacks, original
  payload address observation, empty lending, incompatible-writer rejection,
  and application-exception propagation.
- The complete 22 schema tests, 8 directional-diff tests, 11 generator tests,
  four expected binding-rejection builds, and all 11 Ada smoke executables pass
  under the pinned GNAT 16.2 toolchain with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-bytes/observer slice.
