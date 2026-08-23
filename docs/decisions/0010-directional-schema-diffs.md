# Decision 0010: Directional compatibility uses exact reviewed schema diffs

Status: accepted

Date: 2026-08-23

## Context

Profile 1 readers may accept selected writer fingerprints, but length-delimited
fields alone do not make an unknown value safe. Compatibility can require
application policy: an older writer may omit a now-required reader field, or a
newer writer may emit a field the reader must deliberately ignore. Revision
numbers and broad family membership cannot authorize either behavior.

The family also promises never to reuse a retired field, enum, or variant tag.
A lock containing only active tags cannot prove that promise across releases.

## Decision

Each record, enumeration, and variant lock contains a strictly ordered
`reserved_tags` array disjoint from its active tags. Consecutive family locks
pass a lineage check that requires a growing revision, retains every prior
reservation, moves every removed active tag into the reserved set, and rejects
reactivation of a reserved tag. A value-kind change within a family is rejected
because it would end a nested tag scope and make its reservation history
unprovable; such a breaking encoding change uses a new family ID.

Compatibility is checked in the direction `Reader_Accepts_Writer`. The diff
refers to the exact writer and reader fingerprints. It proves, recursively:

- family, profile, and value kinds agree;
- every writer numeric, length, scalar-count, and dimension-count set is a
  subset of the reader's accepted set;
- every writer enum or variant tag exists in the reader;
- matching record fields have the same presence rule and value compatibility;
- matching defaulted fields have identical canonical default bytes; and
- nested record, sequence, optional, and variant values satisfy the same rules.

Kind, presence, default, range, writer enum, and writer variant changes that
the conservative model cannot prove are structural incompatibilities. A policy
approval cannot override them.

A writer-only record field produces one `ignore_writer_field` requirement. A
reader-only required field produces one `construct_reader_field` requirement.
Reader-only optional and defaulted fields need no approval because their
absence has a complete schema meaning.

The diff report is deterministic JSON and has a SHA-256 fingerprint. A
compatibility approval names both schema fingerprints, that exact diff
fingerprint, and one ordered resolution for every requirement with no extras.
A construction resolution contains canonical Profile 1 wire bytes validated
against the reader field type. An ignore resolution names only the exact
writer field path.

Generated accepted-writer tables and writer-specific decode branches come only
from a structurally clean diff plus a valid approval. The generator also
derives the accepted writer's maximum payload size from its lock for resource
policy; neither the edge nor its approval changes either schema fingerprint.

## Consequences

- A handwritten codec can use the same reports and approvals as a generated
  codec; it does not gain a broader unknown-field rule.
- Compatibility remains exact-fingerprint and auditable without placing JSON,
  hashing, or dynamic dispatch in the runtime crate.
- Presence transformations beyond the two initial requirements fail closed.
  They can be added only as separately specified actions with generated-code
  semantics and boundary tests.
- Family lineage and directional decode compatibility remain distinct: a
  schema may be a valid later family revision while being incompatible with an
  earlier reader.
