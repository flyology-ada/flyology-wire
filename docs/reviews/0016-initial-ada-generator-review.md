# Review 0016: Initial schema-lock-to-Ada backend

Scope: decision 0011, binding validation, deterministic generation, exact
measurement, caller-buffer encoding, transactional exact-schema decode,
generated fixture parity, and Type IR separation.

Review date: 2026-08-23

## Findings and resolution

- P1: Allowing arbitrary Ada type expressions or source fragments in a binding
  would make the generator a source-injection boundary. Inputs are now bounded
  Ada identifiers/expanded names, reject reserved words, and use closed scalar
  enumerators rather than source expressions.
- P1: A manifest could silently omit, duplicate, reorder, or retarget a field.
  Validation now requires increasing tags, case-insensitively unique component
  names, exact schema-fingerprint agreement, and one binding for every root
  field with no extras.
- P1: Decoding directly into a constrained record component could raise during
  `out` copy-back before wire bounds were checked. Numeric values now decode
  into raw 64-bit temporaries and are range-checked before candidate assignment.
  Generated extreme-value aggregates diagnose narrower component subtypes, and
  the test project now promotes all warnings to errors so the Ada legality gate
  rejects such a binding for this exact-scalar milestone.
- P1: A failed decode could expose a partially assigned record. The generated
  decoder initializes the `out` item first, mutates only a local candidate, and
  copies it only after every required field and value check succeeds.
- P1: A short destination or invalid source could be detected after output
  mutation. Generated encode calls exact `Measure`, validates representability
  and destination length, and only then initializes its writer.
- P1: The first generated measure guarded an arithmetic status known to be
  initialized, producing compiler warnings and obscuring data flow. The first
  field now establishes the status directly; later fields are guarded by the
  preceding result. Kind-specific visibility clauses avoid unused warnings.
- P2: Unbounded names, aggregates, or many required-field conditions could
  violate the repository's 110-column generated-source contract. Binding names
  have explicit limits and rendering wraps aggregates and conditions; a larger
  synthetic record freezes the line bound.
- P2: A generated file could drift independently from its schema or manifest.
  Standard tests render both files, compare exact bytes, and the CLI's
  `--check` mode is part of the repository test script.

## Verification

- The initial generator tests cover deterministic output, line
  bounds, closed/exact manifests, name rejection, field coverage/order,
  unsupported presence, signed ZigZag lowering, and declaring-unit context.
- The generated package builds warning-free with GNAT 16.2 under `-gnatwe` and
  instantiates the shared static codec contract.
- Stock GNAT 15.3 directly compiles the generated package and its runtime
  closure with all warnings, validity checks, UTF-8, and the 110-column style
  check enabled.
- `generated_codec_smoke` proves descriptor identity, exact/max measurement,
  invalid-value rejection, nonmutation on short encode, canonical byte parity
  with the handwritten codec, exact round trip, unapproved-writer rejection,
  required-field rejection, invalid Boolean rejection, exact-schema
  unknown-tag rejection, and no partial publication. Review 0018 covers the
  subsequently added approved compatibility paths.
- A second committed signed fixture compiles the generated
  `Interfaces.Integer_64` path and proves both range endpoints, canonical
  ZigZag bytes, out-of-range measure/decode rejection, and transactional
  failure publication.

No open P0, P1, or P2 finding remains in this initial backend slice.
