# Decision 0021: Generated variants bind explicit selectors to bounded records

Status: accepted initial milestone

Date: 2026-08-23

## Context

Profile 1 represents a variant as an explicit value tag followed by one
length-delimited canonical record for the selected alternative. Ada can express
variants with discriminated records, ordinary records plus a selector, private
types, or application adapters. The wire generator must not assume an Ada
discriminant layout or expose inactive discriminated components.

## Decision

The initial variant backend binds one required root-record field to an
application-owned flat tagged-union record:

- `ada_component` names the Ada selector component;
- every schema alternative tag maps to one expanded Ada selector literal; and
- every selected alternative record field maps to one distinct Ada scalar
  component.

The binding is closed and tag ordered. It must cover every active alternative
and every required scalar field in that alternative. This first slice supports
Boolean and signed/unsigned 64-bit fields, one variant as the sole root field,
and no compatibility-writer edge. These restrictions fail generation rather
than selecting an implicit lowering.

Measure validates only the selected alternative's payload and derives both its
record size and the enclosing selector/length extent. Encode writes the
explicit selector tag, a shortest payload length, and the selected canonical
record. Unselected application storage is semantically inactive and does not
affect canonical bytes.

Decode validates the complete outer extent, selector, payload framing, selected
record tags, scalar encodings, ranges, and required fields into an unpublished
candidate. It initializes all application storage deterministically, assigns
the selector and selected fields, and publishes only after the complete root
record succeeds. Undeclared or retired selector tags return `Invalid_Value`;
noncanonical framing or unknown fields in an exact-schema alternative return
`Noncanonical`.

The mapping never derives selector tags from Ada declaration order, position,
representation values, discriminant constraints, or physical layout. A future
Type IR adapter may validate a discriminated-record construction strategy, but
must lower it through this explicit semantic variant model and a reviewed
construction policy.

## Consequences

- The same wire variant can adapt to different Ada representations without
  changing its family or fingerprint.
- Canonical encoding ignores inactive storage and decode resets it, preventing
  hidden application bytes from perturbing or leaking through the payload.
- The generated codec remains allocation-free and uses caller-owned contiguous
  storage with exact pre-measurement.
- Direct discriminated-record construction, nested variants, richer
  alternative field kinds, borrowed alternative views, and compatible-writer
  variant evolution remain later reviewed extensions.
