# Review 0001: Minimum runtime boundary

Scope: the initial `Flyology_Wire` byte, identity, descriptor, status, and
static codec-contract packages; the handwritten smoke codec; the Alire crate
boundary; and decision 0001.

Review date: 2026-08-23

## Findings and resolution

- P1: An all-zero schema fingerprint initially remained usable in a codec
  descriptor. The fingerprint now reserves zero as an invalid sentinel,
  descriptor validation checks it, and tests cover both family and fingerprint
  sentinels.
- P1: Direct compatibility with `Ada.Streams.Stream_Element_Array` did not by
  itself guarantee an eight-bit wire octet on every target. The root package
  now rejects a non-eight-bit stream element at compile time.
- P2: The smoke test initially relied on an encode/decode round trip, which
  could hide a shared byte-order defect. It now compares encoded output with an
  independently specified canonical byte sequence at a nonzero array bound.
- P2: Failure coverage omitted zero profile decoding and invalid-value encode
  destination preservation. Both paths now have fail-closed tests.
- P2: Descriptor memory could be mistaken for an envelope ABI. Decision 0001
  now states that every identity field is canonically encoded and record memory
  is never transferred.
- P2: A generic private type can technically have controlled or resource-owning
  semantics that a source-shape generator cannot infer safely. Decision 0001
  now requires explicit reviewed adapters for those types.

No P0, P1, or P2 finding remains open for this milestone.

## Verification after fixes

- The library and nested smoke-test crate build with the exact Flyology GNAT
  16.2 Alire toolchain.
- The smoke test passes with GNAT 16.2 and GNAT 15.3.
- Handwritten Ada was run through GNATformat with the owning GPR projects and
  compiled with the repository's 110-column limit.
- Source inspection found no Flyology, remoting, Libadalang, access type,
  address overlay, unchecked conversion, I/O, or container dependency in the
  runtime packages.
