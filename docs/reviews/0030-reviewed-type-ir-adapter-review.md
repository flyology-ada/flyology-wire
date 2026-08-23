# Review 0030: Attested Type IR adapter

Scope: decision 0023; dependency attestation, validation-profile separation,
closed record lowering, generated artifacts, CI pinning, and offline/runtime
dependency direction.

Review date: 2026-08-23

## Findings and resolution

- P1: The first implementation emitted Ada component names from Type IR's
  diagnostic `name`, which is intentionally absent from the semantic
  fingerprint. It now derives conventional Ada casing from structural
  `canonical_name`, separately requires case-fold agreement with `name`, and
  rejects a presentation-only mutant that retains the semantic fingerprint.
- P1: Shape-kind inspection alone could lower a derived or constrained Boolean
  type through the built-in Boolean binding. The initial adapter now requires
  the exact public `Standard.Boolean` declaration, direct type form, canonical
  identity, no base or alternate-view references, and exact Known false through
  true static range and predicate facts. Derived and constrained mutants are
  rejected.
- P1: Verifying checker bytes and then importing the original path left a
  time-of-check/time-of-use interval. The adapter now imports isolated copies
  of the attested checker and schema bytes and retains their temporary root
  through the one `load_checked` call.
- P2: The isolated dependency root initially relied on interpreter-shutdown
  cleanup. `Attested_Checker` now gives it an explicit context-manager lifetime;
  the focused suite passes with `ResourceWarning` promoted to an error.
- P2: Decision 0023 incorrectly said the overlay supplied Ada type/unit names
  and that the adapter itself invoked the Ada backend. The decision now records
  that checked canonical identities supply names and that backend generation is
  the next pipeline phase.
- P2: Output aliases could overwrite an input, the reviewed Type IR checkout,
  or another output. The command now resolves and rejects all such paths before
  reading the dependency or writing an artifact.

## Verification

- The consumer lock pins Type IR commit
  `78e6726a80d02b22f573fed3f65538cafd89fc0d`, checker SHA-256
  `b2fdca4cd44c6d64a62ce0e60dd14eac049b0dac29e03bceed9232a2603a1ad2`,
  and schema SHA-256
  `1318d40affd3a7316f79ea3ec61eada70265942bfa41fb2b6ea0f8357348bf49`.
- Ten adapter tests cover exact artifact reproduction, strict-versus-fixture
  provenance, dependency drift, complete component/tag mapping, structural
  bounds, predicates and use-site constraints, semantic identity, diagnostic
  names, exact Boolean identity, optional semantics, and output aliases.
- The adapter reproduces converted-record wire fingerprint
  `e22a7c3cfffe460e9d1b8c8288bf2794e79a3f9ff52dc3d6558bafcae1dc6cc1`
  from reviewed Type IR semantic fingerprint
  `e5f5da08e77e057960fe9ab987b3400e5557a017ae62fcdaa8d4e376042d7f76`.
- The complete 23 schema tests, 8 directional-diff tests, 15 generator tests,
  10 adapter tests, five expected binding-rejection builds, and all 15 Ada
  smoke executables pass under the pinned GNAT 16.2 toolchain.
- Independent Type IR consumer-boundary review and both fix re-reviews report
  no remaining P0, P1, or P2 finding. Serde's independent consumer review also
  reports no P0, P1, or P2 conflict with the wire lowering boundary.

No open P0, P1, or P2 finding remains in this adapter slice. Production
extraction remains intentionally unavailable: the default `strict` profile
admits no current extraction document, and `fixture_shape` requires an explicit
test-only option plus exact reviewed source and semantic digests.
