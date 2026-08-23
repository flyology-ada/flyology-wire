# Contributing

Every architecture or implementation change uses a review cycle:

1. Record a new or changed architecture decision under `docs/decisions/`.
2. Implement the smallest coherent change and its failure-path tests.
3. Run formatting, builds, tests, and repository checks.
4. Review the complete diff separately from implementation, including public
   contracts, allocation and ownership, malformed input, arithmetic, Ada
   accessibility, compatibility, and dependency direction.
5. Fix all P0 and P1 findings before completion. Fix P2 findings as part of the
   same change unless a written decision records why deferral is safer.
6. Re-run verification after every review fix and inspect the final diff.

P0 means data loss, memory unsafety, authentication or identity confusion, or
an unusable public contract. P1 means a correctness, compatibility,
boundedness, ownership, or dependency-boundary defect. P2 means a maintainability
or resilience issue that can reasonably ship only with explicit review.
