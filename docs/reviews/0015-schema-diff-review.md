# Review 0015: Directional schema diff and compatibility approval

Scope: decision 0010, reserved-tag lineage, recursive directional set
inclusion, deterministic reports, exact approvals, and the v1/v3 writer edges
used by `Profile_1_Test_Codec`.

Review date: 2026-08-23

## Findings and resolution

- P1: Active-only locks could not enforce the accepted no-tag-reuse rule.
  Records, enumerations, and variants now carry ordered, disjoint reserved-tag
  sets. Consecutive evolution checks require removal-to-reservation, retain all
  reservations, and reject reactivation.
- P1: Placeholder older and future fingerprints let the Ada compatibility
  fixture drift from offline schema authority. All three identities now come
  from committed locks and the Python suite reconstructs every Ada fingerprint
  byte-for-byte.
- P1: Treating all length-delimited writer-only fields as automatically safe
  would recreate permissive unknown-field handling. Each such field now emits
  an exact `ignore_writer_field` requirement bound to both fingerprints and a
  reviewed diff fingerprint.
- P1: Inferring a missing required reader field from Ada initialization would
  make construction policy invisible. The older edge explicitly approves the
  canonical Boolean `false` bytes for field 2, and the tool validates those
  bytes against the reader lock.
- P1: Matching defaulted fields with different defaults would decode absence
  differently. The diff rejects different canonical defaults as structural
  incompatibility.
- P1: A tag-bearing value kind could disappear and later return, evading a
  consecutive reserved-tag check because the intermediate kind had no tag
  scope. Family lineage now rejects every value-kind change; a breaking
  encoding change requires a new family ID.
- P1: An approval path was initially resolved before proving it matched a diff
  requirement, permitting malformed input to reach an internal lookup. Exact
  action/path matching and closed resolution shape now precede value lookup;
  malformed default hexadecimal also fails through the schema status path.
- P2: Compatibility and lineage were conflated in the first sketch. They are
  separate commands: lineage compares consecutive revisions and compatibility
  compares any exact writer to one reader direction.
- P2: The initial range relation was implicit. Tests now exercise a writer
  range wider than the reader, kind and presence changes, differing defaults,
  invalid construction bytes, missing resolutions, and attempts to approve a
  structural incompatibility.

## Verification

- Twenty-one schema-lock tests and eight schema-diff tests pass using only the
  Python standard library.
- Both consecutive fixture pairs pass lineage validation.
- Both directional fixture reports reproduce their committed JSON and exact
  diff fingerprints; their approvals validate with no unmatched requirement.
- GNATformat 26.0.0 completed for the changed Ada fixture.
- The exact GNAT 16.2 Alire library/test builds and all five Ada smoke programs
  pass.
- Stock GNAT 15.3 directly compiles the changed codec and its runtime closure
  with all warnings, validity checks, UTF-8, and the 110-column style check
  enabled.

No open P0, P1, or P2 finding remains in this slice.
