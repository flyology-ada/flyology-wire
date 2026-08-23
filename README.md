# Flyology Wire

`flyology_wire` defines bounded, transport-independent wire identities and
statically bound Ada codec contracts. Codecs measure and encode into
caller-owned `Ada.Streams.Stream_Element_Array` storage and report malformed or
incompatible input through status values. Decode receives the writer's schema
identity explicitly so compatibility is not inferred from payload bytes. The
shared size helpers make composed exact measurement overflow-safe. The crate
performs no I/O and has no dependency on Flyology or remoting.

The current milestone contains the minimum runtime surface needed by
`flyology_remoting` and the allocation-free scalar, field-header, extent, and
cursor primitives for canonical tagged Profile 1. A scoped generic extent
lender supports generated two-pass borrowed observers without returning a
view or retaining an access value. The repository also contains the closed
Profile 1 schema-lock format, offline fingerprint validator, directional
compatibility diff, and exact compatibility-approval format. Ada-source
structure now enters through an attested offline adapter for the reviewed Type
IR v1 consumer API. Production extraction remains fail-closed because the
current pinned extractor intentionally emits no IR. The initial deterministic
Ada backend generates a codec for nonempty records containing
required/defaulted/optional scalar fields, required bounded byte/UTF-8 text
fields, required enumerations, or required one-dimensional bounded scalar
sequences from a checked binding manifest. The first variant backend binds a
sole required root field to an application-owned selector and required scalar
alternative records. A requested generated two-pass visitor validates the
complete payload before lending byte or UTF-8 extents in the caller's original
storage. Exact writer locks and
reviewed directional approvals optionally generate bounded compatibility
branches.
Libadalang is a build-tool dependency of the shared `flyology_type_ir`
extractor, not a runtime dependency of this crate.

GNAT 16 is the primary development toolchain. The declared Alire dependency
also permits GNAT 13 through 15 so compatibility can be checked without making
an older compiler authoritative.

Build the library and its nested test crate with:

```sh
alr build
alr -C tests build
tests/bin/wire_smoke
```

Run the schema-lock checks and every Ada smoke program with:

```sh
git clone https://github.com/flyology-ada/flyology-type-ir.git ../flyology-type-ir
git -C ../flyology-type-ir checkout 78e6726a80d02b22f573fed3f65538cafd89fc0d
FLYOLOGY_TYPE_IR_ROOT=$PWD/../flyology-type-ir ./scripts/test.sh
```

The schema-lock and compatibility tools use only Python 3's standard library
and are not Alire or runtime dependencies. Decision 0008 defines the semantic
fingerprint projection; the committed fixtures under `schema/fixtures/`
fingerprint the same three writer identities used by the end-to-end Profile 1
codec test.

The Type IR adapter verifies the reviewed checker and schema content digests
before importing `load_checked(path, profile)`. Its production default is
`strict`; this test-only command proves the complete Type IR fixture to
schema-lock and Ada-binding path:

```sh
python3 tools/type_ir_adapter.py \
  --fixture-shape \
  --check \
  ../flyology-type-ir \
  ../flyology-type-ir/fixtures/wire-record-shape.json \
  schema/fixtures/wire-record-shape.overlay.json \
  schema/fixtures/profile-1-converted-record.lock.json \
  schema/fixtures/profile-1-converted-record.ada-binding.json \
  schema/fixtures/profile-1-converted-record.provenance.json
```

Regenerate or verify the initial Ada fixture with:

```sh
python3 tools/generate_ada.py \
  --compatible-writer \
  schema/fixtures/profile-1-record-v1.lock.json \
  schema/fixtures/profile-1-v1-to-v2.approval.json \
  --compatible-writer \
  schema/fixtures/profile-1-record-v3.lock.json \
  schema/fixtures/profile-1-v3-to-v2.approval.json \
  schema/fixtures/profile-1-record.lock.json \
  schema/fixtures/profile-1-record.ada-binding.json \
  tests/generated
python3 tools/generate_ada.py \
  --check \
  --compatible-writer \
  schema/fixtures/profile-1-record-v1.lock.json \
  schema/fixtures/profile-1-v1-to-v2.approval.json \
  --compatible-writer \
  schema/fixtures/profile-1-record-v3.lock.json \
  schema/fixtures/profile-1-v3-to-v2.approval.json \
  schema/fixtures/profile-1-record.lock.json \
  schema/fixtures/profile-1-record.ada-binding.json \
  tests/generated
```

The parallel `profile-1-signed-record` fixture compiles and executes the signed
ZigZag path rather than relying only on generator-text assertions. The
`profile-1-converted-record` fixture binds the initial Type IR record shape to
named signed and modular Ada types through explicit exact-range conversions.
It neither serializes their in-memory representation nor derives wire bounds
from compiler layout. The `profile-1-defaulted-record` fixture exercises an
all-defaulted record whose
canonical payload is empty. The `profile-1-sequence-record` fixture uses a
definite Ada array plus explicit logical count and exercises element framing,
capacity, and construction-lower-bound checks.
The `profile-1-optional-record` fixture binds separate presence and scalar
components so none remains distinct from a present zero value.
The `profile-1-bytes-record` fixture binds a definite stream-element array and
explicit logical length. It exercises exact copy construction, static capacity
and lower-bound rejection, and generated callback-scoped observation without a
payload copy.
The `profile-1-text-record` fixture uses the same definite octet-storage model
with explicit UTF-8 intent. It enforces both octet and Unicode-scalar bounds,
rejects malformed text before encoding or callbacks, and performs no implicit
Ada `String` transcoding.
The `profile-1-enumeration-record` fixture proves that explicit value tags do
not derive from Ada literal positions or representation values. The
`profile-1-variant-record` fixture applies the same rule to selectors and
length-delimited alternative records while ignoring inactive application
storage.

Architecture and implementation changes follow the mandatory review cycle in
[`CONTRIBUTING.md`](CONTRIBUTING.md). The initial runtime boundary is recorded
in [`docs/decisions/0001-runtime-boundary.md`](docs/decisions/0001-runtime-boundary.md).
The corresponding review record is under [`docs/reviews/`](docs/reviews/).

## Agent setup

Flyology Wire provisions shared Ada-library agent instructions and skills
through [APM](https://microsoft.github.io/apm/). Install APM 0.28.0 and the
exact dependency revision in `apm.lock.yaml`, then reproduce the committed
Codex resources with:

```sh
apm install --frozen
apm compile --target codex
apm audit --ci
```

The repository-specific instruction source is under `agent-packages/`; the
root `AGENTS.md` is generated and committed so an agent can use the repository
without a setup step.
