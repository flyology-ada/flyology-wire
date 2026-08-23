# Review 0003: Proposed canonical tagged profile 1

Scope: the proposed Profile 1 grammar, canonical value rules, compatibility,
boundedness, schema fingerprint, alternatives, and separation from relocatable
in-memory layouts.

Review date: 2026-08-23

## Findings and resolution

- P1: The draft described varint integers without bounding the supported Ada
  range, while the initial runtime and generated arithmetic are 64-bit. The
  profile now limits implicit integer derivation to 64 bits and requires an
  explicit adapter or later profile for wider values.
- P1: The first sequence rule provided only one element count and did not state
  how multidimensional shape or Ada lower bounds survive. It now encodes one
  length per schema-known dimension and explicitly excludes varying semantic
  lower bounds from implicit Profile 1 derivation.
- P2: A generic tagged format can accidentally accept arbitrary unknown tags.
  The proposal instead rejects unknown tags for an exact fingerprint and skips
  only tags named by a generated directional compatibility edge.
- P2: Reusing a familiar tag grammar could imply Protocol Buffers
  interoperability. The alternatives section now states why Profile 1 is a
  separate stricter grammar and links the upstream noncanonicality guidance.

No P0, P1, or P2 review finding remains open in the proposal. The architecture
decision itself remains open until the user accepts the durable format choice.
