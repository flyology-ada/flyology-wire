# Decision 0008: Schema lock and semantic fingerprint projection

Status: accepted

Date: 2026-08-23

## Context

Profile 1 requires a stable 32-byte schema fingerprint, while the future
generator will consume structural facts whose declaration IDs, source
locations, diagnostics, and provenance are useful for extraction but are not
wire semantics. Hashing Type IR or an authoring overlay directly would make
source moves, renames, formatting, or tool diagnostics change a wire identity.

Compatibility edges are directional reader policy. Adding an accepted older
writer must not retroactively change the local writer schema's fingerprint.

## Decision

The generator expands the checked structural model plus wire overlay into a
closed Profile 1 schema lock. The semantic root contains only:

- lock format and version;
- nonzero family ID, schema revision, and Profile ID;
- recursively expanded value encodings;
- stable numeric active and reserved field, enum, and variant tags;
- scalar ranges, byte/count bounds, construction lower bounds, presence rules,
  and canonical default wire bytes.

The semantic root contains no Ada or Type IR declaration ID, source name,
source location, generic-instantiation spelling, toolchain provenance,
diagnostic text, file path, compatibility acceptance edge, generated Ada name,
or physical representation fact. Those remain in authoring inputs, validation
reports, or generated-code provenance.

All lock strings are ASCII. Arbitrary-precision signed integers use normalized
decimal strings in the interchange, while Profile 1 validation restricts
their magnitude to the selected 64-bit scalar, count, or construction domain.
Schema-value nesting is limited to 64. Opaque bytes use lowercase hexadecimal. Object keys are
lexicographically sorted with no insignificant whitespace; arrays retain their
defined semantic order. Fields, enum values, variant alternatives, and their
reserved-tag sets are strictly increasing by tag. Active and reserved sets are
disjoint.

The lock's `fingerprint` is lowercase hexadecimal SHA-256 over the canonical
UTF-8 bytes of the complete lock object with only the `fingerprint` member
removed. The canonical bytes contain no trailing newline. The committed lock
includes the fingerprint for independent validation.

Directional compatibility manifests and generated accepted-writer tables are
separate artifacts. They refer to complete schema identities and reviewed
diffs but do not participate in either schema's fingerprint.

## Type IR adapter seam

The schema-lock builder receives a validated, closed structural adapter rather
than Libadalang nodes or raw Type IR JSON. The adapter must provide resolved
declarations, views, generic actuals, use-site constraints, exact variants, and
typed constants, and must prove that required consumer features were accepted.
The eventual Type IR reader may implement that adapter only after Type IR
publishes its reviewed schema, fixtures, features, and Strict Consumer entry
point.

## Consequences

- Source reformatting, moving, and renaming cannot perturb the fingerprint when
  the checked logical structure and overlay policy remain the same.
- Lock diffs describe wire-semantic changes without Type IR or generator audit
  noise.
- The schema lock is a durable wire artifact, not an in-memory IPC layout or a
  serialization of Ada compiler metadata.
- The lock validator and fingerprint tool are offline tooling and introduce no
  runtime dependency.
