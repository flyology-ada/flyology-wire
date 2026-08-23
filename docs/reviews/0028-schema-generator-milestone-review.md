# Review 0028: Schema-to-codec milestone integration

Scope: decisions 0008 through 0021 as one integrated pipeline; documentation
currency, local/release/remote verification, generated-fixture freshness,
review closure, and CI action diagnostics.

Review date: 2026-08-23

## Findings and resolution

- No P0 or P1 integration finding remained after the individual decision
  reviews. The runtime dependency direction, caller-buffer contract, exact
  schema identity, transport-independent bytes, static contract, and
  unpublished-candidate decode remain unchanged.
- P2: Decisions 0009 and 0011 still described implemented enum, variant,
  optional/default, compatibility, and observer slices as future work. Their
  checkpoint text now names decisions 0012 through 0021 and distinguishes the
  remaining Type IR adapter gate from completed schema-lock-to-Ada work.
- P2: The README's phrase “schema derivation” could be read as saying the
  implemented semantic-lock generator did not exist. It now says specifically
  that Ada-source derivation through Type IR remains pending.
- P2: The first remote run reported transitive Node.js 20 deprecation
  annotations from the pinned `setup-alire` v6.0.0 action and a nonfatal cache
  save warning. Upstream's single reviewed v6 follow-up commit updates its
  action dependencies for Node.js 24. CI now pins that exact immutable commit
  (`1ff7d9224297858cc9ecce29b08bc6109f93e49a`) rather than a moving branch.

## Verification

- Local `./scripts/test.sh` passes 23 schema tests, 8 directional-diff tests,
  14 generator tests, four expected-rejection builds, and 14 Ada smoke
  executables with warnings promoted to errors.
- `alr -n build --release` passes.
- `git diff --check` passes and committed generated output matches the
  deterministic renderer.
- `apm install --frozen`, `apm compile --target codex`, and `apm audit --ci`
  pass all ten audit checks with no resource drift.
- GitHub Actions run 32666830282 passes macOS, Ubuntu, and release jobs at
  commit `49c9ef79689287013804dd71bcf1013517e29ca5`; agent-resource run
  32666830294 also passes. The action-dependency pin correction is verified by
  the succeeding remote run before this review closes.

The Type IR adapter is not treated as a review defect: decision 0009 requires a
reviewed Type IR commit/schema/features/fixtures/Strict Consumer entry point,
and that external handoff is not yet published. The schema-lock and binding
seam deliberately remains unlocked until it is.
