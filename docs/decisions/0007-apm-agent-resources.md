# Decision 0007: APM-managed agent resources

Status: accepted

Date: 2026-08-23

## Context

Flyology Wire initially committed a handwritten `AGENTS.md`. Other current
Flyology repositories instead keep repository-specific instruction sources in
a local APM package and compose them with the shared Ada-library profile. A
handwritten generated target can drift from those common rules and has no
reproducible provenance.

## Decision

Use APM 0.28.0 to provision agent resources. The root `apm.yml` composes one
local repository instruction package with
`flyology-ada/agents`' `packages/profiles/ada-library` profile. Commit the
resolved `apm.lock.yaml` and generated root `AGENTS.md`; ignore installed
modules and client-specific deployed resources.

CI installs APM 0.28.0, replays the lockfile with `apm install --frozen`,
regenerates Codex instructions, runs `apm audit --ci`, and rejects changes to
the committed generated file or lockfile.

## Consequences

- Repository-specific wire boundaries remain reviewable under
  `agent-packages/repository` rather than being hidden in generated output.
- Shared Ada source, interface-value, decision-authority, workflow, review,
  commit, and skill resources use one pinned upstream revision.
- Updating shared rules is an explicit lockfile change and therefore receives
  the same review cycle as any other repository change.
- APM is contributor and CI tooling only. It is not an Alire or runtime
  dependency of `flyology_wire`.
