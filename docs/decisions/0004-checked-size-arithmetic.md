# 0004: Exact measurement uses shared checked size arithmetic

Status: accepted

## Decision

`Flyology_Wire.Sizes` supplies allocation-free checked addition,
multiplication, and accumulation over `Byte_Count`. An overflow is an explicit
status, not an exception. Failed addition and multiplication publish zero;
failed accumulation leaves the caller's total unchanged.

Generated codecs and handwritten adapters use these operations for every
variable or composed exact-size calculation and translate `Overflow` to
`Codecs.Size_Overflow`. Statically computed maxima use the same arithmetic in
the generator and reject an unrepresentable complete maximum.

## Rationale

Exact `Measure` is part of the caller-buffer contract. Relying on Ada modular
arithmetic, suppressed checks, or backend-specific helpers could wrap a size
and cause remoting to allocate a destination smaller than the canonical
payload. Central checked operations make the failure contract testable and do
not depend on the eventual payload profile.

## Consequences

- Size calculation remains independent of native array index width.
- A measured size may be representable by `Byte_Count` but not by one Ada
  stream array; `Fits_In_Buffer` remains the separate checked boundary.
- Encoding still measures and rejects insufficient storage before modifying
  the destination.
