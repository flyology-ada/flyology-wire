# Review 0006: Initial independent repository

Scope: the complete initial repository diff, public API, tests, manifests,
project files, documentation, dependency direction, and publication boundary.

Review date: 2026-08-23

## Findings and resolution

- P1: `Size_Bound` used a dynamic predicate, while descriptor validation did
  not independently reject `(Known => False, Value => nonzero)`. With assertion
  checks disabled, that invalid value could pass as a valid codec descriptor;
  with checks enabled, construction could raise instead of returning a status.
  The predicate is removed and a total `Is_Valid (Size_Bound)` operation now
  enforces both unknown and known forms.
- P1: The internal smoke codec used proposed production `Profile_ID = 1` for a
  fixed test encoding unrelated to the proposed tagged grammar. It now uses
  the maximum profile value, explicitly reserved within the test fixture, so
  golden bytes cannot be mistaken for Profile 1 vectors.
- P2: An independent sibling repository needs durable agent rules rather than
  inheriting them accidentally from the Flyology checkout used to bootstrap
  it. `AGENTS.md` now records the dependency, runtime, review, formatting, and
  verification contracts locally.
- P2: The test descriptor's explicit test-only profile referenced the identity
  child package without its own context clause. The clean test build exposed
  the nontransitive visibility error; the test specification now explicitly
  withs `Flyology_Wire.Identities`.

No P0, P1, or P2 finding remains open for the initial repository.

## Verification after fixes

- GNATformat completed for every changed Ada source.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and nested
  test crate and the smoke test passes.
- A direct GNAT 15.3 compatibility build and smoke-test run pass with strict
  warnings, validity checks, overflow checks, and the 110-column style limit.
- `git diff --cached --check`, the shell syntax check, the Ada line-length
  check, and the forbidden-runtime-dependency scan pass.
- Generated Alire, object, library, configuration, and executable artifacts are
  ignored and absent from the staged repository.
