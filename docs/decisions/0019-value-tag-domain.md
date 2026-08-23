# Decision 0019: Enum and variant tags share the five-octet tag domain

Status: accepted

Date: 2026-08-23

## Context

Decision 0003 fixed record field tags at `1 .. 2**29 - 1` but originally left
the upper bound of enumeration and variant tags open. Leaving value tags at the
full unsigned 64-bit varint range would give schema authors a second tag domain
with a ten-octet worst case, while providing no current compatibility benefit.

Ada enumeration positions and representation values are application details.
They are not stable wire identities and do not determine whether an integer is
in the Profile 1 tag domain.

## Decision

Profile 1 field tags, enumeration literal tags, and variant alternative tags
all use the inclusive range `1 .. 2**29 - 1` (`1 .. 536_870_911`). Zero is
invalid. Active and retired tags use the same range, remain disjoint, and are
strictly increasing in schema locks.

All three tag kinds use shortest unsigned base-128 varints and therefore occupy
at most five octets. Lengths, counts, and ordinary unsigned scalar values retain
their separate 64-bit domains and may occupy up to ten octets.

The schema lock and executable validator keep field-tag and value-tag
definitions separate so their semantic roles cannot be confused, even though
their numeric ranges are equal. Generated codecs map enum literals and variant
alternatives only through explicit overlay tags. They never derive a tag from
declaration order, `Enum'Pos`, an enumeration representation clause, or a
source location.

Widening a tag domain changes the accepted Profile 1 grammar and is not a
compatible schema-only evolution. It requires a separately reviewed profile
revision or replacement profile.

## Consequences

- Every tag has the same bounded five-octet representation.
- The existing 29-bit `Field_Tag`/`Tag_Number` runtime machinery can validate
  enum and variant selector tags after decoding without a second tag type.
- The range still supplies more than five hundred million stable identities per
  record, enum, or variant family.
- Schema authors must assign explicit stable tags and permanently reserve
  removed ones.
