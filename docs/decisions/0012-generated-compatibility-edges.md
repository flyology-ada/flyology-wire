# Decision 0012: Generated compatibility edges consume exact approvals

Status: accepted initial milestone

Date: 2026-08-23

## Context

Decision 0010 defines directional diffs and exact policy approvals, while
decision 0011 initially generated only an exact-schema decoder. Leaving the
connection handwritten would allow the accepted-writer table, construction
defaults, ignored tags, and resource bounds to drift from their reviewed
schema artifacts.

## Decision

The Ada generator accepts zero or more repeated pairs of one complete writer
lock and one compatibility approval. For every pair it regenerates the
directional diff against the local reader, rejects structural
incompatibilities, and validates the approval against the exact writer,
reader, and diff fingerprints. Duplicate or local writer fingerprints are
rejected. Valid entries are ordered deterministically by revision and
fingerprint rather than command-line order.

Generated specifications expose each exact accepted writer identity and its
maximum encoded payload size derived from that writer lock. Generated bodies
build the shared runtime accepted-writer table and classify the supplied
writer identity before inspecting payload bytes. Exact local writers and
listed compatible writers remain distinct cases; revision or family membership
never grants compatibility.

The initial required-scalar record backend supports these approved actions:

- `construct_reader_field` for Boolean, signed 64-bit, and unsigned 64-bit
  local fields, using canonical Profile 1 bytes validated by the approval
  loader; and
- `ignore_writer_field` for bounded non-defaulted byte fields, with the
  generated decoder enforcing that exact writer field's octet bounds before
  ignoring its value. Defaulted ignores remain unsupported because explicit
  encoding of their default would also require a byte-equality rejection.

A field absent from an accepted writer is rejected if it appears in that
writer's payload. A constructed field is assigned only after complete payload
parsing and only for its exact writer identity. An ignored tag is accepted
only for the exact writer and approval that introduced it. Every other unknown
tag remains noncanonical. Decode continues to mutate an unpublished candidate
and publishes it only after all required fields and construction rules are
satisfied.

The generated runtime has no JSON, hashing, diff, approval, Type IR, or
Libadalang dependency. Handwritten codecs may implement the same reviewed
edges through the existing static contract and runtime classifier.

## Consequences

- A schema or approval edit makes committed generated Ada stale and fails the
  standard test gate.
- Remoting can use the generated per-writer maxima to bound a complete payload
  before decode without interpreting schema artifacts at runtime.
- Other ignored value kinds and nested construction remain unsupported until
  their validation and lowering rules receive separate decisions and tests.
- The Type IR adapter remains a separate upstream seam; compatibility policy
  continues to belong to the wire overlay and schema artifacts.
