# 0003: Canonical tagged payload profile 1

Status: proposed; requires user acceptance before implementation

## Context

Flyology remoting needs one payload representation whose bytes are identical in
process-local buffers, shared-memory leases, and network frames. The profile
must support exact measurement, caller-provided contiguous output, bounded
complete-payload decode, strict canonical validation, and directional schema
evolution.

The schema overlay already supplies explicit field and variant tags, bounds,
presence/default rules, and compatibility policy. The payload therefore does
not need to repeat names or a self-describing type graph.

## Proposed decision

Reserve `Profile_ID = 1` for the Flyology canonical tagged profile. A record is
a sequence of fields:

```text
record := field*
field  := tag length value
tag    := shortest unsigned base-128 varint, range 1 .. 2**29 - 1
length := shortest unsigned base-128 varint
value  := exactly length octets
```

Fields occur in strictly increasing tag order. A tag occurs at most once in a
record. Tag zero is invalid and a retired tag is permanently reserved. All
lengths are definite; no sentinel-terminated or indefinite form exists.

The complete top-level payload extent comes from the remoting frame or lease.
Nested records are already bounded by their containing field length. A decoder
rejects nonminimal varints, duplicate or decreasing tags, arithmetic overflow,
an extent outside the containing slice, and trailing bytes.

There is deliberately no wire-kind bit in a field header. The validated writer
`Schema_Identity` selects an exact schema, and the length permits a compatible
reader to skip a field without understanding its value representation.

## Canonical values

Profile 1 uses these schema-selected value encodings:

- Boolean: one octet, exactly zero or one.
- Unsigned integer and modular value of at most 64 bits: shortest unsigned
  base-128 varint.
- Signed integer of at most 64 bits: ZigZag transform followed by the shortest
  unsigned varint.
- Enumeration and variant selector: an explicit nonzero overlay tag encoded as
  an unsigned varint; never Ada position or representation value.
- Byte sequence: its raw octets. The enclosing field supplies the byte length.
- Text: validated UTF-8 selected explicitly by the overlay.
- Record: the recursive record grammar above.
- Sequence or array: one unsigned length for each schema-known dimension,
  followed by one length-delimited canonical element for each element in Ada
  logical iteration order. A one-dimensional sequence has one length. Every
  dimension and total element count is bounded by the schema. Profile 1 does
  not carry Ada lower bounds: the overlay must fix them in the schema or choose
  a canonical construction bound; a value whose varying lower bound is
  semantically significant requires another profile or adapter.
- Optional value outside a record: one presence octet followed, when present,
  by one length-delimited canonical value. Record-field absence is encoded by
  absence of that field tag instead.
- Discriminated variant: explicit variant tag, payload length, and one canonical
  record containing exactly the selected alternative's components.

Wider integer, fixed-width integer, IEEE floating-point, fixed-point, decimal
fixed-point, map, recursive access graph, and class-wide encodings are not
implicit Profile 1 derivations. A later reviewed profile or an explicit adapter
may define them.

## Presence and defaults

The overlay assigns every record field exactly one presence rule:

- `required`: encoded exactly once, including when its value equals an Ada
  default;
- `optional`: absent for none and present exactly once for some, preserving
  `some(default)` as distinct from none; or
- `defaulted`: absent means the declared wire default, canonical encoding omits
  a value equal to that default, and exact-schema decode rejects an explicitly
  encoded default as noncanonical.

A default is a wire-schema value, not an inference from Ada initialization.

## Compatibility and unknown fields

Exact-fingerprint decode rejects every field tag absent from that exact schema.
A generated compatibility table may accept another writer fingerprint in the
same family and profile. Only then may it skip tags that the writer schema and
the accepted compatibility edge identify as ignorable.

Readers never accept an arbitrary unknown tag merely because it is
length-delimited. Handwritten codecs list every accepted writer identity and
apply the same rule.

Compatibility is directional: `Reader_Accepts_Writer`. Reordering or renaming
does not affect wire compatibility. A tag or retired tag is never reused.
Adding an optional/defaulted field, removing a field, changing a bound, or
adding an enum/variant value is accepted only when the generated directional
diff proves the reader's construction, default, unknown-value, and resource
policies remain valid. Changing a tag, value encoding, profile, or family is
incompatible.

`Schema_Revision` is monotonic family metadata and never substitutes for the
exact `Schema_Fingerprint` or a compatibility edge.

## Schema lock and fingerprint

The wire generator combines checked Type IR with the explicit wire overlay and
emits a canonical schema lock. The 32-byte `Schema_Fingerprint` is SHA-256 over
the canonical UTF-8 lock with its fingerprint field omitted. Family, revision,
profile, structural type references, tags, bounds, presence/default rules, and
compatibility-relevant policies participate in the lock.

The fingerprint detects schema identity; it is not authentication or payload
integrity protection.

## Boundedness

Every variable-length value has an overlay maximum. Generated code computes a
static maximum encoded size with checked arithmetic. A type whose complete
contiguous maximum cannot be derived is rejected by Profile 1 generation rather
than silently receiving an unbounded codec.

Decode validates outer extents before inner values, enforces depth, count, and
byte limits, builds an unpublished candidate, and commits only after canonical
and application validation succeeds. No parser step allocates hidden storage.

Canonical map ordering can require sorting or application-specific ordered
iteration, so maps are intentionally outside the first profile.

## Alternatives considered

### Schema-locked positional encoding

This is smaller but makes field insertion/removal and unknown-field skipping
fragile. It would turn most evolution into a new incompatible family or require
parallel layout grammars.

### Protocol Buffers wire compatibility

The tag/wire-kind grammar has useful evolution properties, but Protocol Buffers
explicitly does not promise canonical serialization, permits field reordering
and duplicate-field merge/last-wins behavior, and has ambiguous length-delimited
unknown values. Calling a stricter incompatible subset "protobuf" would create
the wrong interoperability expectation.

Reference: <https://protobuf.dev/programming-guides/serialization-not-canonical/>

### Deterministically encoded CBOR

RFC 8949 supplies a sound deterministic base, but its general data model,
shortest-width floating rules, tags, and canonical map-key ordering add runtime
surface that the first bounded generated codecs do not need. A CBOR serde
backend remains useful, but it is not automatically the durable remoting
profile.

Reference: <https://www.rfc-editor.org/rfc/rfc8949.html#section-4.2>

## Relationship to relocatable Flyology data structures

Profile 1 encodes logical values through generated observation/construction
adapters. It never copies an arena, vector, map, record representation, offset,
generation, host-order scalar, padding byte, or persisted synchronization state
as a wire value. A relocatable structure can provide a reviewed observer or
builder, but its IPC layout and wire schema remain separate contracts.
