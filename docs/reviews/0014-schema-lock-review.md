# Review 0014: Profile 1 semantic schema lock

Scope: decisions 0003, 0004, 0008, and 0009; semantic projection,
canonical JSON, fingerprinting, closed value shapes, bounds, canonical defaults,
static maxima, Type IR separation, golden fixtures, and Ada identity agreement.

Review date: 2026-08-23

## Findings and resolution

- P1: Hashing authoring or Type IR input would make source names, locations,
  generic spelling, provenance, and diagnostics perturb durable identities.
  The lock is now a recursively expanded, name-free semantic projection; its
  closed top level rejects source and audit metadata.
- P1: The first normalized-decimal grammar accepted `-0`, permitting two
  fingerprint inputs for one integer. Both JSON Schema and the executable
  validator now accept only `0` or a nonzero magnitude with an optional minus.
- P1: Python's JSON values `1.0`, `NaN`, and `Infinity` could bypass or confuse
  integer canonicality. Integral members now require the exact integer type,
  and the loader rejects non-JSON numeric constants.
- P1: Shape validation alone allowed a `default_wire` value that was malformed,
  out of bounds, noncanonical, or not a value of its declared encoding. The
  validator now performs a complete Profile 1 value validation for Boolean,
  integer, enum, bytes, UTF-8 text, record, sequence, optional, and variant
  defaults, including omission of explicitly encoded record defaults.
- P1: Maximum-only byte and dimension bounds did not describe constrained
  values, and byte/text construction bounds were implicit. Locks now contain
  explicit minimum and maximum octet, scalar, and dimension counts plus every
  canonical construction lower bound; the validator checks their ordering and
  cross-domain feasibility.
- P1: A structurally valid lock could still have an encoded maximum beyond
  `Byte_Count`. Recursive checked measurement now derives every complete
  maximum, rejects addition or multiplication overflow, and exposes the result
  for generator and fixture verification.
- P1: Unbounded decimal text and recursive schema nesting could consume
  excessive offline work or reach host integer/recursion failures outside the
  lock diagnostic path. Profile 1 now limits numeric magnitudes to their
  64-bit domains, construction bounds to signed 64 bits, and schema depth to
  64; boundary tests fail closed.
- P1: An all-zero embedded fingerprint conflicted with the runtime identity
  sentinel. Completed locks reject it; `--set-fingerprint` may consume a
  missing or zero placeholder only while producing the completed lock.
- P1: Active-only tag lists could not preserve the Profile 1 prohibition on
  reuse. Records, enumerations, and variants now include ordered, disjoint
  `reserved_tags`; decision 0010 defines the consecutive-lineage proof.
- P2: A single readable fixture did not freeze the byte projection or connect
  it to generated-style Ada. The repository now commits canonical projection
  bytes and an expected digest, verifies them independently with system
  SHA-256, and checks that the Ada codec fixture uses those exact 32 bytes and
  its derived 15-byte maximum.
- P2: Initial tests covered the simple record only. The unit suite now covers
  every Profile 1 value shape, source-metadata rejection, duplicate and ordered
  tags, normalized bounds, default decoding, static overflow, UTF-8 failure,
  JSON numeric closure, fingerprint mismatch, and fingerprint generation from
  a template.

## Protocol authority resolved

Decision 0019 fixes enum and variant tags at the same `1 .. 2**29 - 1`
five-octet range as field tags. The schema and validator retain distinct field
and value tag definitions while enforcing that common bound. Boundary tests
accept `536870911` and reject `536870912` for both value-tag roles.

## Verification performed so far

- Twenty-two standard-library schema-lock tests pass.
- The independently computed SHA-256 of the committed projection is
  `333f54155fba8344278b98983b8ce91eaec6074e3ebdf3e223f7f520d1532c26`.
- The fixture's recursive static maximum is 15 bytes.
- JSON syntax checks pass for the normative schema and fixture.
- GNATformat 26.0.0 completed for the changed Ada fixture.
- The exact GNAT 16.2 Alire build and all five Ada smoke programs pass.
- Direct GNAT 15.3 builds of the changed codec and observer fixtures pass with
  strict warnings, validity checks, overflow checks, and the 110-column style
  limit.
