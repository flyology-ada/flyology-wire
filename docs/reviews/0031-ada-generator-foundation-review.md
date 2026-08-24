# Review 0031: Ada-authoritative generator foundation

Scope: decision 0024; nested Alire generator boundary, defensive wire-metadata
JSON input, SHA-256 wrapper, build matrix, runtime separation, and maintained
test integration.

Review date: 2026-08-23

## Findings and resolution

- P0: The first publication design implied that a retained staging-directory
  identity could make later rename and removal conditional on that identity in
  an adversary-writable parent. Decision 0024 now requires a trusted,
  quiescent destination parent, no-replace publication, and cleanup that leaves
  an entry behind whenever its identity cannot be proved.
- P1: Value and child cursors initially carried only arena positions and could
  alias another or replacement document. Every cursor now carries a globally
  nonwrapping snapshot identity and rejects foreign, identical-bytes foreign,
  stale, and exhausted identities.
- P1: Rejected replacement initially cleared a previously published document.
  Decode now constructs parser, arena, cursors, and validation state privately,
  releases the parser, and swaps the document only after complete success.
- P1: Duplicate-key handling initially depended on an allocating third-party
  exception message. A bounded wire-owned preflight now detects duplicates
  without exception-text inspection and maps only the parser's documented
  malformed-input exception at the parse boundary.
- P1: The private JSON tree initially had an unconstrained generic surface and
  unapproved public limit defaults. It is now private behind exact wire-format
  and version discrimination, requires a complete caller-supplied limit set,
  names its string limit as an aggregate byte budget, and cannot accept Type IR
  interchange as wire metadata.
- P1: The first input-handling design used canonicalize-then-reopen and left a
  time-of-check/time-of-use interval. Decision 0024 now requires retained-parent,
  no-final-symlink-follow regular-file opens and parses and hashes those exact
  open bytes. Check mode likewise uses one retained directory and a closed
  artifact-name set.
- P1: Signed JSON values initially used implementation-defined
  `Long_Long_Integer`. The model, parser instance, queries, and tests now use
  `Interfaces.Integer_64` with exact endpoint and overflow rejection.
- P1: Indexed linked-edge traversal and third-party object lookup could perform
  unaccounted quadratic work. Child traversal is snapshot-bound and O(1) per
  edge. Decode reserves one work unit per source byte before scanning, then
  charges duplicate candidates, compared key bytes, and a conservative bound
  for each third-party object lookup.
- P1: The first parser-release fault injection remained in the production
  implementation. GPR now selects private enabled or disabled hook units; the
  disabled unit exposes literal `Enabled := False` and imported sentinels, and
  maintained development and release checks prove that the sentinel reference
  is absent from the production object.
- P1: `-U` compiled every generator source but did not bind or link the CLI on
  a clean checkout. Maintained development and release workflows now perform a
  normal executable build followed by a separate all-source compilation.
- P1: The initial maintained suite and release job did not compile the nested
  implementation closure or cover GNAT 15. The root suite invokes the nested
  tests, release CI builds and compiles all generator sources, and a separate
  GNAT 15 job runs the generator suite.
- P2: Canonical integer preflight accepted negative zero and lacked exact
  signed-underflow coverage. It now rejects `-0`, values outside signed 64-bit
  bounds, decimals, exponents, leading zeroes, and incomplete tokens.
- P2: Direct coverage now includes all cursor and child traversal operations,
  exact resource boundaries, arbitrary source lower bounds, format/version
  mismatches, malformed backslashes, transactional semantic rejection, and
  parser-release failure without partial publication.
- P2: CLI version authority was duplicated, the empty install artifact list
  named an absent resource, and decision wording described future commands as
  already implemented. The CLI uses Alire's generated crate version, no empty
  install artifact is declared, and decision 0024 distinguishes the current
  help/version foundation from the completed migration surface.
- P2: Dependency and distribution wording was incomplete. Decision 0024
  records the accepted exact JSON and SHA-256 commits, their generator-only
  scope, Alire pin non-propagation, and the prohibition on advertising a
  separately installable generator until a reviewed reproducible distribution
  mechanism exists.

## Verification

- `flyology_wire_generator/scripts/test.sh` passes under GNAT 15.3.1 and GNAT
  16.1.0. It builds and runs the CLI, hashing tests, defensive JSON tests, and
  development/release disabled-hook elision checks.
- `FLYOLOGY_TYPE_IR_ROOT=<checkout-at-78e6726> ./scripts/test.sh` passes the
  nested generator tests, 23 schema-lock tests, 8 schema-diff tests, 15 Ada
  generator tests, 10 Type IR adapter tests, runtime/test builds, binding
  rejection builds, and all maintained smoke executables.
- `alr -C flyology_wire_generator -n build --release` and
  `alr -C flyology_wire_generator -n build --release -- -U` pass for the nested
  generator under GNAT 16.1.0.
- `apm audit --ci` reports no drift and all ten cached policy checks pass.
- Three independent final review passes report no remaining P0, P1, or P2
  finding across Ada correctness, adversarial input/lifetime behavior, and
  architecture/release boundaries.

No open P0, P1, or P2 finding remains in this foundation slice. Python remains
only as the explicitly transitional conformance oracle; no Python generator
path is newly introduced by this change.
