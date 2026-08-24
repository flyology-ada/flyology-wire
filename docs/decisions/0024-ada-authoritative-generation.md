# Decision 0024: Wire generation is Ada-authoritative

Status: accepted architecture; migration in progress

Date: 2026-08-23

## Context

The first wire generator slices were implemented as offline Python programs so
the schema-lock model, compatibility rules, Type IR seam, and generated Ada
contract could be exercised while the Type IR consumer API was still being
designed. Those programs are now substantial enough to be an accidental second
implementation language and packaging boundary. Flyology projects use Ada for
their authoritative implementation unless an external boundary inherently
requires another language.

Type IR is likewise moving its model, validation, canonical JSON, checked
documents, indexes, attestation, and Libadalang extraction authority to Ada.
Wire must consume those Ada capabilities without adding Type IR, Libadalang,
JSON, or generator dependencies to the `flyology_wire` runtime crate.

## Decision

Add a nested offline Alire executable crate named `flyology_wire_generator`,
with Ada root `Flyology_Wire_Generator`. The runtime crate remains a separate
dependency-free library. Apart from application-owned value/type units,
generated codecs depend only on `flyology_wire`; they never depend on the
generator, JSON, Type IR, Libadalang, or a serde runtime.

The generator owns these Ada packages:

- a closed wire overlay model and validator;
- the Profile 1 schema-lock model, validation, canonical projection, SHA-256
  fingerprint, maximum-size calculation, and canonical JSON writer;
- directional compatibility, lineage evolution, and approval validation;
- consumer-specific Type IR lowering;
- Ada binding validation and naming;
- deterministic Ada rendering; and
- transactional artifact and manifest publication.

`flyology_type_ir` owns the checked structural document, immutable indexes,
structural diagnostics, canonical Type IR JSON, dependency/resource
attestation, and extraction authority. Wire does not copy those facilities or
expose their types through its runtime API. No common serde/wire generator
framework is introduced unless concrete duplicated Ada code later survives an
independent boundary review.

## Extraction authority

Production generation links the Type IR extractor library and lowers an opaque
authority-bearing checked document returned by that same in-process extraction
operation. A JSON document cannot manufacture extraction authority, even when
its bytes, semantic fingerprint, and provenance fields validate.

Loading a persisted Type IR document remains useful for fixtures, audits, and
reproducibility checks. That path returns a structurally or consumer-validated
document without production extraction authority and cannot be passed to the
production generation entry point. The distinction is represented by separate
Ada types or capabilities rather than a Boolean or profile string.

Wire retains the limited checked-document owner for the entire lowering. Model
and index observations are constant and scoped to that owner; access values or
cursors that can outlive it are not retained. Process-level attestation is a
Type-IR-owned Ada library operation that verifies and reads the exact bytes in
one scope. A helper executable that checks a path before another process reopens
it is not an authority boundary.

## Wire JSON boundary

Wire's schema locks, overlays, bindings, approvals, and output manifests are
closed ASCII metadata formats. The generator may use a small Ada JSON library
behind a private wire-owned defensive wrapper. Only closed, format-specific
loaders may use the wrapper; its tree, cursors, and parser types are not a
consumer API. Each loader requires and validates its exact wire format and
version discriminator before publishing a document. In particular, no loader
accepts Type IR interchange as wire metadata. The wrapper must:

- reject duplicate object keys;
- impose caller-supplied source-byte, nesting-depth, node-count,
  per-object-member, aggregate string-byte, and number-token-byte budgets whose
  values are approved by the owning closed format loader;
- reserve one work unit for every source byte before preflight begins, then
  charge every duplicate-key candidate, compared key byte, and bounded
  third-party object-lookup step against the same caller-approved budget;
- reject non-ASCII source bytes and every JSON string escape;
- accept only the exact integer and logical kinds required at each field;
- reject floating-point and exponent spellings where an integer is required;
- restrict JSON number tokens to the signed 64-bit domain; larger wire bounds
  remain normalized decimal strings in the schema model;
- validate closed keys before lowering; and
- convert parser exceptions, allocation failure, and I/O failure into bounded
  nonraising top-level diagnostics and failure status.

These restrictions are valid only because every wire-owned textual field is
already required to be unescaped ASCII identifiers, names, paths, hexadecimal
identities, or fixed policy words. Rejecting every escape also makes duplicate
key comparison independent of alternate escaped spellings. Type IR's canonical
UTF-8 JSON is decoded and encoded solely by `flyology_type_ir`; the wire JSON
wrapper never parses Type IR interchange. Canonical writers are owned by the
semantic model and do not use a parser library's general-purpose image
function.

The wrapper releases the parser successfully before it publishes a decoded
document. A parser cleanup failure is an internal decode failure, not a reason
to continue with publication. Cleanup after an already rejected decode and
limited-owner finalization is best effort and cannot turn rejection into
success. Parser-documented malformed-input exceptions are classified only at
the parse boundary; an indexing or range exception from wire-owned conversion
is an internal error.

The upstream Alire `json` 6.0.0 commit was evaluated and does not build under
the selected GNAT 16 toolchain: its own `No_Implementation_Extensions`
configuration rejects the `SPARK_Mode` aspects in its public units. Flyology's
Alire repository already uses the narrowly corrected
`mosteo/onox-json-ada` commit `737296c5e378c33ac823af8404f87ebac0eb2fad`,
which removes that contradictory restriction while retaining
`No_Obsolescent_Features`. Wire uses that established exact pin rather than
patching an Alire cache or creating another parser. Its parser behavior still
requires the wire-owned defensive wrapper and conformance tests above. The
generator accepts Alire `sha2` 2.0.0 at exact commit
`73c2cd73e440b1e36d1b5c8b741fcb0e3fc4046c`; neither dependency enters the
runtime crate.

These exact Git pins are authoritative for building the generator from this
source tree. Alire pins do not propagate through a dependent or installed
crate. The generator is therefore not advertised as a separately installable
release until both exact dependencies are available through an accepted Alire
index release or are distributed by another reviewed reproducible mechanism.

## Commands and transaction

The completed migration will expose one Ada executable with explicit
subcommands for lock validation and inspection, compatibility/evolution
diffing, checked fixture adaptation, production source generation, and
schema-lock/binding-to-Ada generation. Subcommands will share typed Ada models
rather than serialized intermediate files inside one invocation. The current
foundation slice exposes only help and version while it establishes the
dependency, bounded-input, hashing, and build boundaries.

Every input is opened once without following a final symlink, relative to a
retained parent-directory handle. The generator verifies that the opened object
is a regular file, reads it through that same handle, and parses and hashes only
those retained bytes. Canonical-path checks are diagnostics and alias guards;
they never authorize a later reopen. Check mode likewise opens the destination
directory once, rejects symlink or non-regular artifact entries, reads each
artifact through that retained directory handle, and compares a closed name
set without canonicalize-then-reopen behavior.

Generation constructs and validates every output in memory first. Write mode
has an explicit precondition: the retained destination parent is trusted,
quiescent for the complete transaction, and not writable by an adversary. The
generator rejects symlink or hard-link aliases between inputs and destination,
creates its staging name exclusively under that parent, and opens staged files
relative to the retained directory handles. Publication requires an atomic
no-replace rename and fails closed where that operation is unavailable. The
trusted-parent precondition is necessary because portable rename/unlink cannot
make a source-name lookup conditional on a previously opened inode. Cleanup
removes staged entries only while their opened identities still match; if any
identity cannot be proven, it leaves the staging object behind and reports its
location instead of removing by name.

## Migration and verification

Python remains temporarily as a byte-for-byte conformance oracle while each
Ada slice is implemented. The migration order is:

1. schema-lock parsing, validation, canonical projection, SHA-256, and maximum;
2. compatibility, evolution, and approval reports;
3. binding validation and deterministic Ada rendering;
4. fixture-only Type IR lowering through the reviewed Ada checked-document API;
5. production lowering through the in-process Ada extraction authority; and
6. removal of Python from the supported build, test, and packaging paths.

Every slice must reproduce the existing positive artifacts byte for byte,
reject the existing negative corpus, add adversarial parser/resource tests, and
complete an independent P0/P1/P2 review. All P0 and P1 findings and normally all
P2 findings are fixed before that slice is committed. Python files are deleted
only after the corresponding Ada path is authoritative and the parity test no
longer depends on Python.

## Consequences

- `flyology_wire` keeps its current remoting-facing runtime API and dependency
  direction.
- Generator allocation is allowed, but every untrusted input has explicit
  caller-approved limits and every collection traversal is single-pass/linear
  or charges an explicit work budget. Generated codecs retain their
  no-hidden-allocation and caller-buffer contracts.
- Persisted Type IR remains an audit artifact, not proof that GNAT legality and
  exact Libadalang extraction occurred.
- Decision 0023's Python-specific import and same-read mechanism becomes a
  historical transitional implementation once the Ada consumer is complete.
- Production extraction remains fail-closed until the reviewed Ada Type IR
  authority API exists and its strict extractor can produce a document.
