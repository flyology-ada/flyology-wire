# Decision 0009: Wire overlay and generation pipeline

Status: accepted architecture; initial Type IR adapter implemented

Date: 2026-08-23

## Context

Ada source shape does not supply wire family IDs, tags, bounds, presence,
defaults, text semantics, construction policy, or compatibility authority.
Libadalang can resolve source structure but is not a legality checker, schema
authority, or suitable runtime dependency. Wire generation must automate the
structural work without silently inventing durable protocol choices.

## Decision

Use this offline pipeline:

```text
GNAT legality check
  -> pinned Libadalang extractor
  -> checked, versioned Type IR snapshot
  -> strict Flyology Wire structural adapter
  + closed wire overlay
  -> expanded semantic schema lock
  -> fingerprint and directional lock diff
  -> generated Ada codec and optional scoped visitor
```

`flyology_type_ir`, not `flyology_wire`, owns the GNAT project/scenario/target/
runtime invocation and Libadalang extraction. The wire generator never queries
Libadalang directly. Its adapter accepts only a Strict Consumer-valid snapshot
with resolved views, generic actuals, use-site constraints, exact variant
trees, typed constants, required features, and complete extraction provenance.
Every unknown, unsupported, imprecise, unresolved, or mismatched mandatory
fact is a generation failure.

The adapter API is semantic and in-process. It exposes resolved declarations,
components, literals, alternatives, constraints, and source locations for
diagnostics; it does not expose Libadalang handles or make raw Type IR JSON the
generator's internal model. The Type IR reader is implemented only after the
Type IR project publishes its reviewed commit, schema, fixture set, required
features, and validation entry point.

## Wire overlay

The companion overlay is the authority for facts Ada cannot decide. It must
explicitly select:

- one named root declaration and view;
- nonzero family ID, schema revision, and Profile ID;
- a wire lowering for every reachable source type;
- stable field, enum, and complete-variant tags;
- the complete retained set of retired field, enum, and variant tags;
- scalar, octet, scalar-count, and dimension bounds;
- canonical construction lower bounds where Profile 1 omits Ada bounds;
- required, optional, or defaulted field presence and canonical defaults;
- UTF-8 or byte-sequence intent rather than guessing from an Ada array;
- explicit adapters for private abstractions or construction/observation that
  cannot be generated safely.

Every reachable structural component, literal, discriminant alternative, and
generic actual is either mapped exactly once or rejected. Declaration order,
`Enum'Pos`, representation clauses, source locations, and physical layout are
never fallback tags or identities. A private full view is not inspected unless
the type's owner supplies an explicit reviewed adapter contract.

Source annotations may provide convenient overlay fragments, but the checked
companion overlay is the normalized authority. Generation does not use
Libadalang's experimental document-annotation API.

Source entity IDs, views, and locations are binding and diagnostic data. The
lowering expands them away before decision 0008's schema lock and fingerprint
projection.

## Eligibility

Profile 1 generation supports only values with a complete allocation-free,
bounded, transactional codec. Boolean, signed and modular integers through 64
bits, explicitly tagged enumerations, definite records, bounded byte/text
sequences, bounded arrays/sequences, explicit optionals, and exact
discriminated variants are eligible when all policies are closed.

Floating and fixed point, maps, recursive access graphs, class-wide values,
anonymous ownership-bearing types, tasks, protected objects, controlled or
resource-owning values, unchecked physical layouts, and unbounded containers
are rejected unless a handwritten adapter supplies a separately reviewed
schema lock and the same static codec contract. An adapter is not permission to
serialize an Ada representation.

## Outputs

For each root, generation emits:

- the semantic schema lock and its independently checkable SHA-256 identity;
- one Ada package containing the descriptor, exact `Measure`, preflighted
  `Encode`, unpublished-candidate `Decode`, and static contract instance;
- a generated scoped `Validate_And_Visit` capability when borrowed byte or text
  observation is requested;
- writer-specific accepted identities and unknown-tag rules only after a
  directional diff against reviewed prior locks succeeds; and
- a provenance report containing source/Type IR/toolchain inputs outside the
  semantic fingerprint.

Generated Ada uses only `flyology_wire` at runtime. The extractor, Type IR,
overlay loader, diff engine, hashing tool, and generator are offline
dependencies.

Generation checks consecutive family locks as a lineage. Every removed active
tag must become reserved, every earlier reservation must remain reserved, and
no active tag may reuse a reservation. Directional reader compatibility is a
separate comparison and is never inferred from revision order alone.

## Initial generator milestone

The first generated fixture is one named definite record containing required
Boolean and signed/unsigned 64-bit fields. It reproduces the committed schema
lock, descriptor, maximum, canonical bytes, and exact-schema failure behavior
now exercised beside `Profile_1_Test_Codec`. Decision 0011 records the narrow
checked binding used before Type IR v1 was available. Subsequent decisions 0012
through 0021 add reviewed compatibility edges, defaults, bounded sequences,
optionals, raw bytes, borrowed observation, UTF-8, enumerations, and an initial
explicit-selector variant lowering. Decision 0022 admits exact-range named Ada
integers, and decision 0023 implements the first attested Type IR record
lowering. Complete Profile 1 derivation is still not claimed: all documented
fail-closed restrictions remain part of the generator contract, and production
source extraction intentionally remains gated.
