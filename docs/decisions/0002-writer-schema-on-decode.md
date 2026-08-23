# 0002: Writer schema is an explicit decode input

Status: accepted

## Decision

`Flyology_Wire.Identities` defines `Schema_Identity`: family, fingerprint,
revision, and profile. Its canonical 56-byte representation concatenates the
opaque 16-byte family, opaque 32-byte fingerprint, unsigned big-endian revision,
and unsigned big-endian profile. Every codec descriptor contains one such
value. `Decode` receives the writer's `Schema_Identity` in addition to the
complete payload bytes.

Remoting reconstructs this value from individually encoded envelope fields and
passes it to the selected codec. The schema value is payload-contract metadata,
not route, session, correlation, or transport state. The Ada record itself has
no stable memory representation.

A codec first validates the identity, then accepts an exact schema or a
directionally compatible writer schema known to its generated compatibility
table. Every other identity returns `Incompatible` without partially publishing
the destination value.

## Rationale

Payload bytes do not carry their schema identity. Without an explicit writer
identity, a decoder cannot distinguish an exact-schema payload containing an
illegal unknown tag from a compatible newer payload containing an allowed new
field. Always accepting or always rejecting unknown fields would silently make
the compatibility policy part of the byte parser.

Passing the writer identity keeps schema selection and compatibility explicit
without coupling wire to remoting's envelope or transport.

## Consequences

- Remoting passes the validated writer schema from its envelope to `Decode`.
- Generated codecs own their accepted-writer compatibility tables.
- Handwritten adapters must reject every identity they do not explicitly
  support.
- Exact-schema canonical validation and compatible-schema evolution can have
  different unknown-field policies without changing the transport.
