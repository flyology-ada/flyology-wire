# 0001: Minimum runtime boundary

Status: accepted for the first implementation milestone

## Decision

The Alire crate is `flyology_wire` and its Ada root is `Flyology_Wire`. It has
no dependency on Flyology, remoting, Libadalang, or a transport. Remoting and
other consumers depend on it in the outward direction.

Wire payload storage is `Ada.Streams.Stream_Element_Array`. Exact measurement
uses a fixed-width unsigned count, while completed buffer writes use
`Stream_Element_Count`; checked conversion joins the two. This lets Flyology
buffer leases lend their existing arrays without conversion or address
overlay. A target whose stream elements are not exactly eight bits is rejected
at compile time rather than assigned a different canonical representation.

The minimum runtime packages provide stable identity value types, canonical
identity bytes, codec descriptors, status outcomes, and one statically bound
generic codec contract shared by generated and handwritten codecs. Complete
payload decoding is transactional and streaming is excluded from version one.
All-zero family and schema-fingerprint values are reserved invalid sentinels;
schema revisions and profile identifiers are nonzero unsigned 32-bit values.
`Codec_Descriptor` is an Ada value and has no stable in-memory representation;
an envelope encodes its identity fields individually and never copies the
record's memory.

Borrowed-view decoding is deferred. Its intended shape is a generated
callback-scoped observation of a limited opaque view while remoting retains the
payload lease. A freely returnable view is not part of the root contract.

Libadalang extraction and the versioned Ada semantic IR belong to the separate
offline `flyology_type_ir` project. Wire generation combines that IR with an
explicit wire schema overlay; neither tool is a wire runtime dependency.

## Consequences

- IPC and network transports carry identical canonical payload bytes.
- Route, session, correlation, lease, and framing state remain outside wire.
- Codecs allocate no hidden storage and receive complete caller-bounded input.
- The first runtime contract supports definite nonlimited values. Additional
  contracts for limited values require a separate reviewed decision.
- Generated codecs reject controlled or resource-owning semantics unless an
  explicit handwritten adapter supplies separately reviewed ownership,
  allocation, and failure behavior.
- Canonical payload profiles and schema evolution tooling remain later
  milestones and cannot silently change these identity or buffer types.
