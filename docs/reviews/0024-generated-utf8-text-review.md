# Review 0024: Generated bounded UTF-8 text

Scope: decision 0018, UTF-8 octet binding, scalar-count primitive, octet/scalar
bounds, exact measure/encode, transactional decode, scoped observation, and
Unicode semantic boundaries.

Review date: 2026-08-23

## Findings and resolution

- P1: Treating an Ada `String` or arbitrary byte array as implicitly UTF-8
  would hide transcoding and text intent outside the schema. The closed binding
  accepts only the explicit UTF-8 stream-element storage mode.
- P1: Validating during Encode would modify caller output before malformed text
  was discovered. Generated Measure validates the complete logical prefix;
  Encode calls Measure before initializing a writer.
- P1: Counting a valid prefix and returning that count on malformed trailing
  input could let callers apply scalar bounds to an invalid value. The runtime
  overload publishes its local count only after complete validation and returns
  zero on every failure.
- P1: Byte bounds alone do not enforce a schema's scalar resource bound. The
  generator checks both the canonical UTF-8 result and exact scalar count in
  Measure, Decode, and the observer's callback-free first pass.
- P1: Unicode normalization would require an additional semantic policy and
  often temporary storage. Profile 1 explicitly treats valid scalar sequences
  as distinct and performs no normalization.
- P2: A maximum scalar bound at least as large as the maximum octet bound is
  redundant and could produce an out-of-range Ada literal for extreme schemas.
  The generator omits that comparison because a UTF-8 scalar consumes at least
  one octet.
- P2: Generated text-only observers initially risked unused scalar cursor
  declarations under warnings-as-errors. Observer declarations are emitted
  only for the field kinds that use them.

## Verification

- The committed text lock has fingerprint
  `0c21277ce7bfa4af4cae2ebdf8de11169eede970a10f60ba6fc3c0bd5a4cb36a`
  and a static maximum of ten octets.
- Runtime vectors prove exact four-scalar counting across one-, two-, three-,
  and four-octet encodings and zero count after malformed trailing input.
- Twelve generator tests cover the explicit text storage mode, deterministic
  and line-bounded output, UTF-8 validation calls, scalar-bound generation,
  and borrowed extent generation.
- `generated_text_codec_smoke` proves exact measure, canonical UTF-8 bytes,
  empty text, malformed-text and scalar-limit nonmutation, transactional
  decode, original payload-address observation, no callbacks for malformed
  text, empty lending, and callback exception propagation.
- The complete 22 schema tests, 8 directional-diff tests, 12 generator tests,
  four expected binding-rejection builds, and all 12 Ada smoke executables pass
  under the pinned GNAT 16.2 toolchain with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-text slice.
