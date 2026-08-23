# Review 0009: Length-delimited values and UTF-8

Scope: Profile 1 length-delimited measurement/read/write primitives, text
validation, malformed inputs, arbitrary array bounds, and transactional state.

Review date: 2026-08-23

## Findings and resolution

- P1: Sequence elements, optional payloads, and variant payloads need the same
  canonical length grammar as fields without fabricating a field tag. Shared
  length-delimited primitives now use shortest unsigned varints and reserve a
  bounded nested extent.
- P1: Direct lookahead such as `Index + 3` can overflow an Ada array index
  before truncated UTF-8 is diagnosed. Validation advances the already bounded
  relative cursor one octet at a time and never computes an unchecked future
  native index.
- P1: Text validation must reject overlong encodings, surrogate code points,
  values above U+10FFFF, stray continuations, invalid lead octets, and truncated
  sequences. The validator applies the exact second-octet ranges for E0, ED,
  F0, and F4 and rejects every other invalid class.
- P2: The first test build compared one raw octet without making the stream
  element equality operator visible. The explicit visibility clause was added.
- P2: Initial vectors did not cover empty text, U+10FFFF, a bad continuation
  after a valid lead, or an F5 lead. The final golden/corruption set covers all
  four boundaries.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- GNATformat completed for the changed specification, body, and test source.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and both
  smoke programs; both pass.
- A direct GNAT 15.3 build and `tagged_smoke` run pass with strict warnings,
  validity checks, overflow checks, and the 110-column style limit.
- Length-delimited tests cover one- and two-octet lengths, exact extents,
  insufficient output, out-of-container input, nonminimal length, and size
  overflow.
- UTF-8 tests cover one through four octets, empty text, U+10FFFF, overlong,
  surrogate, above-maximum, invalid-continuation, invalid-lead, stray,
  truncated, and invalid-extent cases.
