# Review 0029: Generated user-defined integer conversions

Scope: decision 0022; binding validation, compile-time range checks, exact
measurement, canonical encoding, transactional decoding, and initial Type IR
fixture compatibility.

Review date: 2026-08-23

## Findings and resolution

- P1: Converting a decoded 64-bit primitive to a range, modular subtype, or
  predicate-bearing type can raise instead of returning a decode status. The
  accepted structural contract is now deliberately narrower: the Type IR
  adapter must prove a static contiguous exact range and reject every
  predicate. Generated endpoint aggregates and range pragmas independently
  reject stale range bindings at compilation.
- P1: Allowing an application type wider than the wire range would require a
  runtime Measure rejection and made exact-range fixture checks compile as
  always-false warnings under warnings-as-errors. The initial contract now
  requires equal source and wire ranges. Generated `Compile_Time_Error` guards
  reject any source-type range drift, endpoint aggregates reject narrower
  component subtypes, and Measure therefore converts only values already in
  the wire domain.
- P1: Publishing a converted field before later validation would violate the
  codec transaction contract. Decode validates the raw primitive first and
  mutates only its local candidate; the destination receives the complete
  candidate only after every required field succeeds.
- P1: Returning a Profile 1 primitive through the current borrowed observer
  would misrepresent an application-typed field. Validation rejects converted
  scalar bindings whenever that observer is requested.
- P2: Nested conversion expressions exceeded the generated 110-column limit.
  Scalar size arguments now have a deterministic continuation form, and the
  committed generated output is line-bounded.
- P2: Text assertions alone would not prove Ada visibility, modular conversion,
  endpoint checks, or warnings-as-errors behavior. The `Wire_Shape` fixture
  compiles the Type IR team's initial Boolean/signed/modular record shape, and
  a separate rejected build widens its signed type by one value to exercise the
  compile-time guard.

## Verification

- The converted-record lock has fingerprint
  `e22a7c3cfffe460e9d1b8c8288bf2794e79a3f9ff52dc3d6558bafcae1dc6cc1`
  and a static maximum of 13 octets.
- Fifteen generator tests cover the closed representation form, invalid kind
  and key rejection, explicit encode/decode conversions, endpoint aggregates,
  deterministic generation, and line-bounded output.
- `generated_converted_codec_smoke` proves exact bytes for the signed and
  modular endpoints, exact measurement, round trip, raw out-of-range rejection,
  and deterministic failure publication under the pinned GNAT 16.2 toolchain
  with warnings promoted to errors.
- The generated binding rejection suite proves that an application range drift
  fails with the reviewed compile-time diagnostic.
- The complete 23 schema tests, 8 directional-diff tests, 15 generator tests,
  five expected binding-rejection builds, and all 15 Ada smoke executables pass
  after the review fixes.

No open P0, P1, or P2 finding remains in this converted-integer slice.
