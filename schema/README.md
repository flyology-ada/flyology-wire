# Wire schema locks

`schema-lock-v1.schema.json` defines the closed JSON shape of a Profile 1
schema lock. The executable validator additionally enforces semantic rules
that JSON Schema cannot express directly: ordered active and reserved tags,
disjoint tag sets, normalized and ordered 64-bit bounds, bounded schema depth,
canonical default payloads, a representable static maximum, and the SHA-256
fingerprint projection from decision 0008.

Validate a lock and its embedded fingerprint:

```sh
python3 tools/schema_lock.py schema/fixtures/profile-1-record.lock.json
```

Inspect its fingerprint, canonical fingerprint input, or derived maximum:

```sh
python3 tools/schema_lock.py --fingerprint schema/fixtures/profile-1-record.lock.json
python3 tools/schema_lock.py --projection schema/fixtures/profile-1-record.lock.json
python3 tools/schema_lock.py --maximum-size schema/fixtures/profile-1-record.lock.json
```

`--set-fingerprint` accepts an otherwise valid document whose fingerprint is
missing, all zero, or stale, and prints a sorted readable lock with the computed
fingerprint. It does not update a file in place.

The fixture is intentionally free of Ada names and Type IR identifiers. It
describes the same family, revision, profile, fields, fingerprint, and 15-byte
maximum as `Profile_1_Test_Codec`. The attested adapter in
`tools/type_ir_adapter.py` now produces the converted-record lock and Ada
binding from the reviewed Type IR fixture plus a closed wire overlay. Its
production profile remains fail-closed until the pinned extractor can produce
a Strict Consumer document.

`schema_diff.py` compares a complete writer lock to a reader lock. It emits a
deterministic directional report, rejects structural incompatibilities, and
requires an exact reviewed resolution for each policy-bearing construction or
ignore decision:

```sh
python3 tools/schema_diff.py \
  schema/fixtures/profile-1-record-v1.lock.json \
  schema/fixtures/profile-1-record.lock.json
python3 tools/schema_diff.py \
  --approval schema/fixtures/profile-1-v1-to-v2.approval.json \
  schema/fixtures/profile-1-record-v1.lock.json \
  schema/fixtures/profile-1-record.lock.json
```

Family evolution is a separate check over consecutive revisions. It requires
revision growth, retention of every reserved tag, and reservation of every
removed record, enum, or variant tag:

```sh
python3 tools/schema_diff.py --evolution \
  schema/fixtures/profile-1-record-v1.lock.json \
  schema/fixtures/profile-1-record.lock.json
```

The `.ada-binding.json` fixture is generator binding data, not wire semantics.
It binds the exact lock fingerprint and every root field tag to checked Ada
names and one supported scalar representation. It is excluded from the schema
fingerprint and does not replace the wire overlay or Type IR adapter. Decisions
0011 and 0023 record this boundary.

The parallel signed and all-defaulted fixtures compile generator paths that the
main compatibility fixture does not exercise. Default values come only from
validated `default_wire` bytes; decision 0013 defines omission, reconstruction,
and explicit-default rejection.

The Ada generator can also consume repeated `--compatible-writer WRITER_LOCK
APPROVAL` pairs. It recomputes and validates each exact directional diff,
emits exact accepted-writer identities and maxima, and lowers only the reviewed
actions supported by decision 0012. These pairs remain wire-overlay policy;
they are not inferred from Ada declarations or Type IR.

The sequence binding uses `ada_component`, `ada_length_component`, and
`ada_element_scalar` rather than `ada_scalar`. Decision 0014 defines its
one-dimensional logical-prefix contract and compile-time capacity/lower-bound
checks.

An optional scalar binding adds `ada_present_component`. Decision 0015 defines
why hidden value storage is unobserved when this Boolean component is false and
why present default-looking values remain encoded.

An enumeration binding supplies a complete explicit `ada_literals` map from
each schema value tag to one expanded Ada literal name. The mapping never uses
Ada position or representation values. Decision 0019 fixes both enum and
variant value tags at `1 .. 2**29 - 1`.

The initial variant binding uses `ada_component` for an application-owned
selector and a complete `ada_alternatives` map for selected record payloads.
Only required Boolean and 64-bit integer alternative fields are currently
lowered. Decision 0021 defines the flat tagged-union contract and its deliberate
fail-closed restrictions.

## Remoting task-control locks

`schema/remoting/` contains the six reviewed Profile 1 locks for task start,
cancel, and observation requests and replies. Decision 0025 assigns their
semantic field and variant meanings and defines why one start attempt uses two
strictly adjacent request messages: the generated control request followed by
the separately leased application initialization payload with its own envelope
schema identity. The locks add no Remoting dependency to the Wire runtime.

The maintained schema-lock tests validate every embedded fingerprint, family
uniqueness, and exact maximum encoded size:

```sh
python3 tools/test_schema_lock.py
```
