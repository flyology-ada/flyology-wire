# Review 0020: Generated bounded sequences

Scope: decision 0014, varying logical counts, definite capacity, construction
lower bounds, exact measurement, element framing, caller-buffer encode,
transactional decode, malformed/canonical classification, and negative binding
gates.

Review date: 2026-08-23

## Findings and resolution

- P1: Iterating an Ada array without proving its construction lower bound would
  silently map a different application index domain to the same wire value.
  Generated Ada now raises a compile-time error unless the array's first index
  equals the schema construction lower bound.
- P1: A schema maximum above the bound array's capacity could pass offline
  validation and fail only on some values at runtime. A separate compile-time
  capacity check rejects the binding; runtime measure and decode retain the
  defensive capacity check.
- P1: Converting a nested `Measure_Status` to `Encode_Status` by enumeration
  position would couple unrelated status declaration orders. The generated
  encoder now maps every status explicitly with a case statement.
- P1: A sequence decoder could accept bytes beyond the declared element count
  because the field extent is already framed. It now requires the nested cursor
  to end exactly after the declared number of elements and reports trailing
  bytes as noncanonical.
- P1: Decoding directly into the destination array would publish a prefix when
  a later element was malformed or out of range. Count, elements, and unused
  capacity are constructed only in a local candidate and copied after the root
  required-field check.
- P1: Encode could modify the destination before discovering an invalid count
  or element. The complete root measure validates both before writer
  initialization; the short-destination path remains nonmutating.
- P2: Positive compilation alone did not prove the new static checks fire.
  Standard tests now run two expected-failure projects and require the exact
  insufficient-capacity and wrong-lower-bound diagnostics.
- P2: A count minimum of zero generated an always-false unsigned comparison,
  which failed the warning-as-error gate. Zero lower checks and domain-maximum
  upper checks are omitted when the scalar type already proves them.

## Verification

- The committed sequence lock and binding reproduce fingerprint
  `540d120e71dc57b20e42a5afbbb4f8802d3f75f5a449db5cf0a57c9bb21db413`
  and a 15-byte static maximum.
- Ten standard-library generator tests cover committed output, rank rejection,
  distinct storage/count components, binding closure, scalar paths,
  compatibility approvals, and line bounds.
- `generated_sequence_codec_smoke` proves exact and maximum measure, invalid
  count and element rejection, nonmutation on a short destination, canonical
  nonempty and empty encoding, round trip, truncated-element classification,
  excess-count rejection, trailing-element rejection, and transactional
  failure publication.
- Both invalid binding projects fail with their required compile-time
  diagnostics.
- The complete Python suites and all ten Ada smoke executables pass under
  GNAT 16.2 with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-sequence slice.
