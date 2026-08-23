# Decision 0023: Type IR enters wire generation through an attested one-read adapter

Status: accepted initial milestone

Date: 2026-08-23

## Context

Decision 0009 leaves Ada-source derivation behind a strict adapter seam until
`flyology_type_ir` publishes a reviewed commit, schema, fixture, required
features, and validation entry point. Wire must consume the resolved semantic
model without copying its validator, treating JSON syntax as semantic intent,
or adding Libadalang to the runtime or generator.

The Type IR consumer API retains the exact bytes it reads, the parsed document,
the semantic projection and fingerprint, the source-byte digest, and the
validation profile in one `CheckedDocument`. Its production `strict` profile
and test-only `fixture_shape` profile have intentionally different provenance
admissibility.

The reviewed v1 dependency is commit
`78e6726a80d02b22f573fed3f65538cafd89fc0d`. The consumer lock attests
`schema/type-ir-v1.schema.json` and `scripts/check_fixtures.py` by the SHA-256
digests published with that commit.

## Decision

The wire repository records one closed Type IR consumer lock containing:

- the upstream repository and reviewed commit SHA;
- the relative checker and JSON Schema paths plus their SHA-256 content
  digests;
- the supported IR version and complete required-feature list; and
- the reviewed wire fixture path, source digest, and semantic fingerprint used
  by the end-to-end test.

The offline adapter accepts a Type IR root, one Type IR document, one closed
wire overlay, and output paths. It verifies the checker and schema bytes against
the consumer lock before importing an isolated copy of those exact bytes. It
calls only `load_checked(path, profile)` and lowers `CheckedDocument.document`
from that same read. It never reopens the Type IR input. A Git checkout is
useful for provenance but is not a validation mechanism; content attestation
is the executable dependency boundary.

Production invocation always requests `strict`. The `fixture_shape` profile is
available only with an explicit test-only option and is rejected for ordinary
generation. Structural validation alone is never sufficient for wire
generation.

## Closed wire overlay

The overlay binds one semantic root declaration ID and semantic fingerprint to
the durable choices that Ada structure cannot supply:

- family ID, schema revision, and Profile ID;
- generated package name;
- one stable wire tag and presence policy for every mapped component;
- one explicit wire lowering and numeric bounds for every mapped type; and
- the retained reserved-tag set.

The adapter derives the root Ada type, component identifiers, and declaring
compilation units from canonical checked Type IR identities. The initial
lowering accepts one public, definite, nonlimited, untagged, nonabstract,
nondiscriminated record with directly owned required components. Components
may be exactly `Standard.Boolean` or named signed/modular integer types with a
Known static contiguous range, Known false predicate, no use-site constraint,
and a range within Profile 1's 64-bit domain. The overlay repeats numeric
bounds as wire policy; the adapter requires exact equality with the resolved
source range before emitting decision 0022's exact-range Ada binding.

The overlay cannot grant visibility, replace a Known fact, resolve an
Unknown/Unsupported fact, select a private full view, or omit a reachable
component. Declaration order, source names, source locations, physical
representation, and Type IR semantic IDs do not become wire tags or schema
identity.

## Outputs and transaction

The adapter constructs the schema lock and Ada binding entirely in memory,
validates both with the existing closed validators, and computes the wire
schema fingerprint before writing. A later pipeline phase invokes the existing
deterministic Ada backend at its schema-lock/binding seam. Check mode compares
every output; write mode uses same-directory temporary files and replacement
so an individual artifact is never partially written.

A nonsemantic provenance report records the Type IR dependency lock, validation
profile, Type IR source/semantic digests, overlay digest, and emitted wire
fingerprint. Those values are audit inputs, not part of canonical payload bytes
or the wire schema fingerprint.

## Consequences

- `flyology_wire` retains no runtime, Alire, Ada, or Libadalang dependency on
  `flyology_type_ir`; the adapter is an offline Python tool boundary.
- Updating Type IR checker or schema bytes is an explicit reviewed consumer-lock
  change even when the IR version number is unchanged.
- The first end-to-end fixture proves the adapter architecture but is not
  production provenance; production source derivation remains fail-closed
  until `strict` admits an extractor-produced document.
- Enums, variants, defaults, arrays, generics, private adapters, and broader
  integer domains require later reviewed overlay lowerings even when Type IR
  already models their structure.
