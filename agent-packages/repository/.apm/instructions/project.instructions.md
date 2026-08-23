---
description: Flyology Wire architecture, codec, review, and verification rules.
---

# Flyology Wire agent guide

Read `README.md`, the relevant decision record, and the implementation before
making repository-grounded claims or changes.

## Project boundary

- The Alire crate is `flyology_wire`; the Ada root is `Flyology_Wire`.
- Runtime code must not depend on Flyology, remoting, Libadalang,
  `flyology_type_ir`, a transport, or a format-neutral serde runtime.
- Remoting may depend on wire. Wire must never depend on remoting.
- Route, session, correlation, lease, framing, I/O, and transport metadata stay
  outside this crate.
- Canonical wire bytes are independent of transport and in-memory layout.
  Never encode an Ada record representation, native address, access value,
  padding byte, relocatable arena image, persisted lock, or host-order scalar.

## Runtime contracts

- Use `Ada.Streams.Stream_Element_Array` storage without array conversion or
  address overlays. Support arbitrary array lower bounds.
- Codecs allocate no hidden storage. `Measure` is exact, `Encode` writes into
  caller storage, and complete-payload `Decode` is bounded and transactional.
- Failures use explicit status values. A failed encode publishes zero bytes and
  leaves the destination unchanged; a failed decode publishes no partial value.
- Family IDs, fingerprints, revisions, profiles, tags, bounds, defaults, and
  compatibility rules are explicit schema data. Never derive them from Ada
  declaration order, enumeration position, representation clauses, source
  locations, or in-memory layout.
- Generated and handwritten codecs satisfy the same statically bound contract.
- Libadalang and the shared Type IR are offline generator inputs only.

## Workflow

- Run `git status --short --branch` before editing and preserve unrelated work.
- Use `rg` and `rg --files` for discovery and `apply_patch` for hand edits.
- Keep handwritten Ada within 110 columns. Run `gnatformat -P` with the owning
  project after Ada changes; both projects set UTF-8 and the width explicitly.
- Use `alr build`, `alr -C tests build`, and `tests/bin/wire_smoke` for the exact
  development build. Keep GNAT 15 compatibility checked while GNAT 16 remains
  the primary toolchain.
- Every architecture and implementation change follows `CONTRIBUTING.md`.
  Fix all P0/P1 findings and normally every P2 before commit, rerun checks after
  fixes, and record the review under `docs/reviews/`.
- Keep commits focused and use the Flyology Problem/Solution commit format.
- Always run `gh` outside the sandbox. Repository:
  `flyology-ada/flyology-wire`.
