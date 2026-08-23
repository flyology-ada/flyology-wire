# Decision 0013: Generated scalar defaults are wire defaults

Status: accepted initial milestone

Date: 2026-08-23

## Context

Profile 1 says a defaulted record field is absent when its value equals the
wire-schema default, and exact decode must reject an explicitly encoded
default. Ada component initialization is not wire authority, so the generator
must lower the canonical default bytes already present in the validated schema
lock rather than inspect or infer an Ada default expression.

## Decision

The initial scalar record backend accepts both `required` and `defaulted`
Boolean, signed 64-bit, and unsigned 64-bit fields. For every defaulted field,
generation decodes the lock's already validated canonical `default_wire` bytes
into one typed Ada literal. That literal is binding data for generated logic;
it does not change the schema lock or fingerprint.

Generated `Measure` and `Encode` omit a defaulted field exactly when the Ada
component equals that semantic default. Measurement remains exact when the
first field is omitted and when every field is omitted. A record containing
only default-valued fields therefore has a canonical zero-byte payload inside
its already bounded outer frame.

Generated `Decode` parses any present field canonically, validates its scalar
range, and rejects it as noncanonical if its semantic value equals the field's
default. After the complete payload has parsed, every absent defaulted field is
assigned its schema default in the unpublished candidate. Required-field and
compatibility construction checks then run as before, and the destination is
published only after all checks succeed.

The static maximum retains every defaulted field at its maximum encoded size,
because a nondefault value may be present. No Ada declaration default,
initialization expression, source name, or representation clause participates.

## Consequences

- Default omission and reconstruction are deterministic consequences of the
  schema lock, not application initialization behavior.
- All-defaulted records are valid and exercise zero-size measure/encode/decode
  paths without hidden allocation or sentinel bytes.
- Decision 0015 supplies the separate explicit-presence lowering needed to
  distinguish optional none from `some(default)`.
- Nested and nonscalar defaults remain unsupported by the initial Ada backend
  until their typed construction and equality rules are generated and reviewed.
