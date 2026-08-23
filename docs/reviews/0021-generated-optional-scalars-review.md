# Review 0021: Generated optional scalar fields

Scope: decision 0015, explicit presence, hidden-value semantics, exact measure,
zero-byte none, present default-looking values, range validation,
transactional decode, and generated-source warnings.

Review date: 2026-08-23

## Findings and resolution

- P1: Reusing defaulted-field equality for optional values would collapse
  present zero/false into absence. Optional inclusion depends only on the bound
  presence component; no scalar value is treated as an absence sentinel.
- P1: Validating the hidden value while presence is false would reject a state
  that the wire schema defines as none. Generated range checks are guarded by
  presence in measure, and encode observes no hidden value when absent.
- P1: Treating every field with no default as required would reject an absent
  optional at the final decode gate. Required tracking now follows the schema
  presence rule explicitly; optional fields need no seen flag.
- P1: Decoding a present field without setting application presence would
  publish the right scalar as none. The candidate presence component is set
  only after canonical scalar and range validation succeeds.
- P2: The generated optional-only package initially declared a seen flag that
  was never read, failing the warning-as-error contract. Seen state is emitted
  only for required/defaulted fields that consume it.
- P2: A zero-byte none path needed independent coverage from default omission.
  The committed fixture proves none, present zero, present upper bound, hidden
  invalid storage, invalid present storage, and trailing scalar bytes.

## Verification

- The committed optional lock and binding reproduce fingerprint
  `3123f3bb00829124b457fcd5cbaaa8e3b30a3dfd2b09ad949c560a35865e2597`
  and a three-byte static maximum.
- The schema and generator suites validate the fixture and committed generated
  Ada, including conditional range checks, explicit presence assignment, and
  absence of a required-field gate.
- `generated_optional_codec_smoke` proves zero measure/encode for none,
  nonobservation of hidden invalid storage, preservation of present zero,
  upper-bound round trip, invalid-present rejection, trailing-byte rejection,
  and transactional failure publication.
- The complete Python suites, both expected binding failures, and all ten Ada
  smoke executables pass under GNAT 16.2 with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-optional slice.
