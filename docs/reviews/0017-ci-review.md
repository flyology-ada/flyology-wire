# Review 0017: Repository CI and generated-fixture gates

Scope: cross-platform full tests, release build, minimum Python version,
generated-output freshness, action pinning, permissions, and warning policy.

Review date: 2026-08-23

## Findings and resolution

- P1: The repository had no build workflow, so schema fingerprints, generated
  Ada, and the runtime contract could drift after local verification. CI now
  runs the complete script on current Ubuntu and macOS and performs a separate
  release-mode library build.
- P1: The generated binding checks rely on a warning-free legality gate, while
  the test project only enabled warnings. Test compilation now promotes every
  warning to an error with `-gnatwe`.
- P1: Mutable action tags in the APM workflow and a new CI workflow would leave
  checkout/setup execution outside repository review. Checkout, Python setup,
  and Alire setup use immutable commit SHAs; checkout credentials are not
  persisted and workflow permissions remain read-only.
- P2: Local tests used Python 3.9, but no remote job froze that lower bound.
  Both OS jobs explicitly install Python 3.9, and every offline tool and test
  parses and passes under the host's Python 3.9.6 before publication.
- P2: A normal build alone would not detect hand edits to committed generated
  source. `scripts/test.sh` runs all generator unit tests and `--check` before
  compiling or executing the generated codec.

## Verification

- The complete local script passes under GNAT 16.2 with warnings as errors for
  all test and generated units.
- The ten smoke executables pass, including generated/handwritten byte parity
  and the compiled signed ZigZag fixture.
- Stock GNAT 15.3 compiles the generated package with strict warning, validity,
  UTF-8, and style switches.
- All three offline tools and their tests parse under Python 3.9.6; the schema,
  compatibility, and generator suites pass.

Remote CI status is recorded after the reviewed commit is pushed. No open P0,
P1, or P2 finding remains in the workflow definition.
