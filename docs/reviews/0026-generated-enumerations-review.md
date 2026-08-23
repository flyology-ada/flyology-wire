# Review 0026: Generated required enumerations

Scope: decision 0020; explicit literal mapping, tag-domain enforcement,
measurement, canonical encode/decode, failure publication, and Ada binding
checks.

Review date: 2026-08-23

## Findings and resolution

- P1: Deriving a tag from declaration order, `Enum'Pos`, or a representation
  clause would make application layout a durable wire contract. The binding is
  a complete explicit schema-tag-to-literal map, and generated code contains no
  ordinal or representation conversion.
- P1: A partial map could compile while failing at runtime for an unhandled
  literal. Validation requires exact schema tag order and one unique Ada literal
  per active value; generated case coverage is checked by the Ada compiler.
- P1: Publishing a decoded component before discovering an unknown tag would
  violate the codec transaction contract. Decode mutates only a local candidate
  and publishes it after the complete required record validates.
- P1: An unknown selector is a semantically invalid value, not malformed
  framing. The generated decoder returns `Invalid_Value`; overlong varints
  remain `Noncanonical`.
- P2: Expanded literal names might be accepted by the offline generator but be
  stale or refer to the wrong type. Generated compile-time record aggregates
  force GNAT to resolve every mapped literal against the bound component.
- P2: Enum-only codecs initially emitted an unused `Interfaces.Unsigned_64`
  operator visibility clause under warnings-as-errors. Visibility is now
  emitted only when a non-enum generated path uses unsigned operators.

## Verification

- The committed enum lock has fingerprint
  `0641281e8a4609eee8e94b22a5a06574b975172f58592f1732e0a5708e662fea`
  and a static maximum of three octets.
- Thirteen generator tests cover complete order-preserving mapping, duplicate
  rejection, deterministic generation, and line-bounded output.
- `generated_enumeration_codec_smoke` maps Ada representation values 42 and 99
  to wire tags 1 and 9; it proves exact bytes, both round trips, unknown-tag
  rejection, overlong-tag rejection, missing-field rejection, and unchanged
  failure publication.
- The complete 23 schema tests, 8 directional-diff tests, 13 generator tests,
  four expected binding-rejection builds, and all 13 Ada smoke executables pass
  under the pinned GNAT 16.2 toolchain with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-enumeration slice.
