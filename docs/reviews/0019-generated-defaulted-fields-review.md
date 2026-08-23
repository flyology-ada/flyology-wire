# Review 0019: Generated defaulted scalar fields

Scope: decision 0013, canonical default authority, exact measure, omission,
explicit-default rejection, all-defaulted records, zero-byte payloads,
transactional decode, static maximum, and generated-source warnings.

Review date: 2026-08-23

## Findings and resolution

- P1: Initial measurement assumed the first field always initialized arithmetic
  state. If that field were defaulted and omitted, the final status could read
  an uninitialized value. Generated measure now initializes the state when the
  first field is defaulted and preserves overflow propagation across later
  conditional and required fields.
- P1: Treating an explicitly encoded default as an ordinary present field
  would create two payloads for one canonical value. Decode now compares the
  fully parsed semantic scalar with the validated wire default and reports
  `Noncanonical` before marking the field present.
- P1: Assigning absence defaults directly to the `out` object could expose a
  partial result after a later field failed. Defaults are applied only to the
  unpublished candidate after complete parsing; publication remains the final
  successful action.
- P1: A zero-byte encoding could accidentally mutate caller storage or fail
  cursor setup. The generated all-defaulted fixture measures zero, initializes
  a zero-length writer extent, writes nothing, reports `Written = 0`, and leaves
  the complete destination unchanged.
- P2: Testing a default after a required first field would not exercise the
  uninitialized-state edge or a record with no required fields. The committed
  fixture makes both scalar fields defaulted and tests empty decode plus
  Boolean and numeric explicit-default rejection.
- P2: A maximum derived from only normally emitted fields would understate
  resource needs. The descriptor continues to use the lock's recursive maximum,
  including every defaulted field at its nondefault maximum.

## Verification

- The committed defaulted lock and binding reproduce fingerprint
  `a0d35862c84637a22dd298936e4dde0c4021517c41dd3e538501f3ddc6c36ef8`
  and a seven-byte static maximum.
- The schema suite validates the new lock, and the generator suite verifies the
  committed spec/body plus default omission, explicit-default rejection, and
  absence construction branches.
- `generated_defaulted_codec_smoke` proves exact zero and maximum measurement,
  nonmutation on zero-byte encode, nondefault encoding, empty-payload default
  construction, Boolean and numeric explicit-default rejection, and
  transactional status behavior.
- The complete Python suites and all ten Ada smoke executables pass under
  GNAT 16.2 with all warnings promoted to errors.

No open P0, P1, or P2 finding remains in this generated-default slice.
