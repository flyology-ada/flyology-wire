# Decision 0018: Generated text stores and validates bounded UTF-8 octets

Status: accepted initial milestone

Date: 2026-08-23

## Context

Ada `String` is an array of `Character`; it does not by itself specify UTF-8,
Unicode scalar semantics, normalization, or an allocation-free construction
policy. Inferring text from an Ada character or byte array would make the wire
schema depend on an unstated transcoding convention.

## Decision

The initial text binding explicitly selects
`utf_8_stream_element_array`. It names a definite
`Flyology_Wire.Octet_Array`-compatible component and a separate unsigned
logical-octet length, using the same capacity and construction-lower-bound
checks as decision 0017. This represents application-owned UTF-8 storage; it
does not reinterpret or transcode an Ada `String`.

The schema supplies minimum/maximum octets and minimum/maximum Unicode scalar
counts. Profile 1 validates shortest-form UTF-8, excludes surrogate code points
and values above U+10FFFF, and counts complete Unicode scalar values. The
scalar-count result is zero on every validation failure, so a caller cannot
mistake a valid prefix count for validation of the whole text.

Generated Measure validates the selected application prefix before computing
its field size. Encode therefore cannot modify output for malformed UTF-8 or a
scalar-bound violation. Decode validates the complete borrowed extent before
copying into its unpublished candidate. Generated borrowed observation applies
the same checks in its callback-free first pass and lends the original UTF-8
octets in the second pass.

Profile 1 does not perform Unicode normalization. Each valid Unicode scalar
sequence is a distinct logical value even when another sequence renders the
same grapheme. Applications that require NFC, NFKC, case folding, or another
equivalence policy need an explicit reviewed adapter/schema policy; the wire
runtime does not allocate a normalization buffer.

## Consequences

- Text intent is schema-visible and cannot be confused with unconstrained
  bytes merely because the Ada storage shape is identical.
- UTF-8 validation and scalar counting are allocation-free and bounded by the
  enclosing field extent.
- Construction copies UTF-8 octets; scoped observation lends them without a
  copy or retainable view.
- Direct generated `String`, `Wide_String`, and `Wide_Wide_String` transcoding,
  optional/defaulted text, and compatibility-writer text visitors remain later
  reviewed extensions.
