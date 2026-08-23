# Review 0011: APM-managed agent resources

Scope: decision 0007, local instruction ownership, pinned dependencies,
generated resources, ignored deployment artifacts, documentation, and CI
reproducibility.

Review date: 2026-08-23

## Findings and resolution

- P1: The repository had only a handwritten `AGENTS.md`, so its shared rules
  had no pinned source or reproducibility gate. A local APM package, shared
  Ada-library profile, lockfile, generated root instructions, and CI replay
  are now present.
- P2: The first `.gitignore` edit used a root-anchored module entry while APM
  itself appends an unanchored entry, producing a duplicate after frozen
  installation. The file now retains APM's stable generated form and only one
  `apm_modules/` entry.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- APM CLI 0.28.0 resolved the local package and shared Ada-library profile at
  the commit recorded in `apm.lock.yaml`.
- `apm install --frozen` reproduced the deployed resources from the lockfile.
- Two consecutive `apm compile --target codex` runs produced the same
  `AGENTS.md` SHA-256 digest.
- `apm audit --ci` passed all ten integrity and drift checks.
- The agent-resource workflow matches the current Flyology sibling pattern
  and verifies `AGENTS.md` plus `apm.lock.yaml` on pushes and pull requests.
- `git diff --check` reports no whitespace error.
- APM remains outside the Alire manifest and runtime dependency graph.
