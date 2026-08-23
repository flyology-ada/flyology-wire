# Review 0018: Generated compatibility edges

Scope: decision 0012, exact artifact binding, deterministic accepted-writer
tables, writer-specific construction and ignore behavior, resource bounds,
canonical validation, and transactional publication.

Review date: 2026-08-23

## Findings and resolution

- P1: An initial ignored-field branch advanced over the framed extent without
  validating the ignored value against its writer schema. That could accept a
  payload the claimed writer could not canonically produce. The initial
  backend now accepts only bounded, non-defaulted byte ignores and emits exact
  minimum and maximum octet checks. Rejecting defaulted ignores also prevents
  explicit encoding of an omitted default from bypassing canonicality. Both
  generated and handwritten fixture decoders reject an oversized ignored
  value.
- P1: Accepting an approval without regenerating its directional report could
  authorize behavior after either lock changed. Generation now recomputes the
  report and requires exact writer, reader, and report fingerprints plus an
  ordered resolution for every requirement and no extra resolution.
- P1: A compatible older writer could smuggle a reader-only field unless the
  generated branch remembered the writer's structural absence. Every local
  field absent from an accepted writer is rejected under that exact identity;
  its approved construction occurs only after parsing succeeds.
- P1: Compatibility failure or late construction failure could partially
  publish a candidate. The `out` value is initialized before classification,
  all decoding and construction target a local candidate, and publication
  occurs only after every required-field check succeeds.
- P2: Command-line order or duplicate writer pairs could perturb generated
  names and tables. Writers are unique, nonlocal, and sorted by revision and
  fingerprint before rendering.
- P2: A caller could lack a static receive bound for a compatible writer.
  Generated specifications expose the maximum encoded size independently
  derived from each validated writer lock.

## Verification

- Ten standard-library generator tests cover deterministic compatibility
  ordering, duplicate rejection, exact approval fingerprints, defaulted-ignore
  rejection, committed output freshness, scalar lowering, binding closure, and
  line bounds.
- `generated_codec_smoke` proves exact identity parity with the handwritten
  codec, approved older-field construction, rejection of fields absent from
  the older schema, future-field ignore, ignored-field bound enforcement,
  exact-schema unknown-tag rejection, and transactional failure publication.
- `profile_codec_smoke` independently enforces the same ignored-field bound in
  the handwritten adapter.
- The complete schema, diff, and generator suites and all ten Ada smoke
  executables pass under GNAT 16.2 with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this compatibility-generation slice.
