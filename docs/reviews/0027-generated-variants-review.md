# Review 0027: Generated required variants

Scope: decision 0021; closed selector/alternative binding, selected-value
semantics, canonical nested framing, exact measurement, transactional decode,
failure classification, static maximum, and generator restrictions.

Review date: 2026-08-23

## Findings and resolution

- P1: Inferring selectors from Ada discriminant position or representation
  would conflate application representation with the wire schema. Every
  alternative uses a complete explicit schema-tag-to-expanded-literal map.
- P1: Validating all fields of a flat application record would make inactive
  storage affect a selected value. Measure and Encode inspect only the selected
  alternative; Decode initializes inactive storage deterministically and never
  treats it as payload.
- P1: Writing a candidate before validating nested framing or all required
  alternative fields would partially publish failed input. Decode publishes
  only after the root field and selected alternative record complete.
- P1: A selector without an exact payload boundary could let one alternative
  consume bytes belonging to its container. Variant payload records are
  length-delimited, nested cursors must end exactly, and the outer variant
  rejects trailing bytes.
- P1: Supporting arbitrary nested schema kinds through an incomplete lowering
  would create silent construction and resource policies. The initial backend
  fails closed unless the sole required variant field contains required
  Boolean or signed/unsigned 64-bit record fields.
- P2: Ada names may resolve offline but target the wrong component or literal.
  Generated record aggregates and typed read/write calls make GNAT check every
  selector literal, payload component, and scalar type.
- P2: A generated unsigned operator and measure-status comparison initially
  lacked the required direct visibility under warnings-as-errors. The renderer
  now emits visibility only for the exact generated operations, and the strict
  build is warning-free.

## Verification

- The committed variant lock has fingerprint
  `4832cec5ea0dc2f80d0e3a0fbc1b83ba284aafe1f3aab6d59def6bffb9996073`
  and a recursive static maximum of eight octets.
- Fourteen generator tests cover deterministic line-bounded output, exact
  selector/field mapping, reversed-alternative rejection, and duplicate
  application-component rejection.
- `generated_variant_codec_smoke` proves exact bytes for both alternatives,
  selector tags independent of Ada representation values 41 and 73, ignored
  inactive storage, selected-range rejection without output mutation,
  deterministic inactive storage after decode, unknown/reserved selector
  rejection, required-field rejection, exact alternative fields, trailing
  value rejection, shortest selector form, and canonical Boolean validation.
- The complete 23 schema tests, 8 directional-diff tests, 14 generator tests,
  four expected binding-rejection builds, and all 14 Ada smoke executables pass
  under the pinned GNAT 16.2 toolchain with warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-variant slice.
