# Review 0007: Borrowed observation contract

Scope: decision 0005, the Flyology buffer-lending API, Ada accessibility,
validation ordering, callback exceptions, and remoting lease ownership.

Review date: 2026-08-23

## Findings and resolution

- P1: The initial architecture preferred a callback-scoped limited view, but
  Flyology lends a non-aliased array. A view retaining that input would require
  a contract Flyology does not supply or an unsafe access/address escape. V1 now
  uses a generated visitor that retains no input reference.
- P1: Visiting while parsing could publish trusted observations before a later
  malformed field invalidated the payload. `Validate_And_Visit` validates the
  complete payload first and invokes application callbacks only on a second
  bounded pass.
- P2: Translating an exception from application visitor code into a decode
  status would hide an application failure and complicate lease cleanup. The
  decision now requires propagation while remoting retains the lease through
  unwinding.
- P2: A runtime class-wide visitor would add dispatch to a contract whose
  generated shape is statically known. The decision requires generic formal
  packages or subprograms.

No P0, P1, or P2 finding remains open for this decision.

## Verification

- The decision was checked against the actual
  `Flyology.Buffers.With_Readable_Data` contract and formal parameter mode.
- The runtime dependency direction is unchanged; wire does not depend on
  Flyology or remoting.
- No source or public runtime API changes are part of this architecture slice.
