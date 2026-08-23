# 0006: Runtime schema selection is exact and directional

Status: accepted

## Decision

`Flyology_Wire.Compatibility` classifies a writer identity against one local
reader identity and a statically generated array of accepted writer identities.
The result distinguishes invalid identities, an invalid accepted-writer table,
the exact local schema, an explicitly compatible writer, and a valid rejected
writer. Classification validates the table itself and fails closed rather than
requiring a separate caller-side check.

An accepted-writer table is valid only when every entry is a valid complete
identity, differs from the local identity, shares its family and profile, and
occurs once. Revision ordering is not inferred: a reader may explicitly accept
an older or newer writer after the offline directional proof succeeds.

The runtime helper compares complete identities. It does not infer
compatibility from family, revision, field layout, or payload bytes. It does not
decide whether an unknown tag may be skipped. For every compatible writer, the
generated decoder owns a closed writer-specific policy derived from the schema
diff; exact-schema decoding continues to reject every unknown tag.

## Rationale

Generated and handwritten codecs need the same identity-selection semantics,
but compatibility proof requires the checked Type IR, schema overlay, bounds,
defaults, construction policy, and both schema locks. Keeping proof offline
leaves the runtime allocation-free and prevents a generic "same family means
compatible" shortcut.

## Consequences

- Compatibility is `Reader_Accepts_Writer`, never symmetric by default.
- A profile change is incompatible even when logical fields appear equal.
- A family change is incompatible and cannot be admitted by a table entry.
- Remoting passes the envelope's complete writer identity unchanged and does
  not classify schemas itself.
- Generated code may specialize the small linear table into a case or search
  structure without changing these semantics.
