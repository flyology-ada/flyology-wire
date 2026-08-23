# Decision 0011: The initial Ada backend consumes a checked binding manifest

Status: accepted initial milestone

Date: 2026-08-23

## Context

The Type IR project has not frozen its consumer schema, features, fixtures, or
Strict Consumer entry point. Binding the wire generator to its draft would
make unresolved extraction semantics an input to durable codecs. The backend
that turns an already validated semantic schema into Ada does not need to wait
for that adapter.

The semantic lock deliberately excludes Ada names. Code generation therefore
needs separate, nonsemantic information identifying the target package, value
type, record components, and scalar representations.

## Decision

The initial offline Ada backend consumes two independently validated inputs:

1. one complete Profile 1 schema lock with its verified fingerprint; and
2. one closed, versioned Ada binding manifest naming that exact fingerprint.

The binding contains only expanded Ada unit/type/package names and an ordered
one-to-one mapping from root field tags to Ada component identifiers and
supported scalar representations. It is not hashed into the schema identity,
is not a wire overlay, contains no Libadalang or Type IR node, and supplies no
family, tag, bound, presence, default, or compatibility authority.

For this milestone, the backend accepts one nonempty record whose fields are
all required and lower to Boolean, `Interfaces.Integer_64`, or
`Interfaces.Unsigned_64`. It emits:

- the exact schema identity and statically derived maximum;
- exact `Measure` with checked size arithmetic;
- preflighted encode into the caller's arbitrary-lower-bound stream array;
- exact-fingerprint decode into an unpublished candidate;
- strict required, tag-order, extent, canonical scalar, and range checks; and
- the statically bound `Flyology_Wire.Codecs.Contracts` instance.

Numeric decode uses raw 64-bit temporaries, validates wire-schema bounds, then
assigns the candidate. Generated extreme-value aggregate checks make a binding
to a narrower component subtype emit static range diagnostics, and the test
project promotes every warning to an error. Incompatible,
malformed, noncanonical, or invalid input leaves the published destination at
a harmless schema-valid aggregate.

The manifest accepts only closed keys, exact integer versions, bounded Ada
identifiers and expanded names, sorted unique context units, increasing tags,
exact scalar-kind claims, and complete root-field coverage. Ada reserved words
and source-text fragments are rejected rather than interpolated.

Generated files are deterministic and committed as fixtures. The test runner
regenerates them in memory and fails if either file is stale. The generated
codec compiles with the ordinary test project and is compared byte-for-byte
and descriptor-for-descriptor with the reviewed handwritten codec.

## Type IR seam

The original fixture manifest is manually reviewed test input. It is not a
general substitute for structural extraction. Decision 0023's reviewed Type IR
adapter now proves component identity, views, constraints, and scalar
compatibility for the first public record shape before constructing this same
binding model. The Ada legality build remains a required final gate.

No Libadalang, Type IR, JSON, generator, or binding type enters the generated
codec's runtime dependency closure.

## Consequences

- Backend development and runtime verification can continue without locking
  against an unstable Type IR interchange.
- This initial slice is intentionally not called complete Profile 1
  derivation. Decisions 0012 through 0021 subsequently add the reviewed
  compatibility, defaulted/optional, bounded-container, observer, text, enum,
  and initial variant slices. Decision 0023 adds the first Type IR lowering;
  its documented restrictions remain explicit completion boundaries.
- Handwritten adapters continue to satisfy the same static runtime contract;
  the generator does not introduce a second remoting codec abstraction.
