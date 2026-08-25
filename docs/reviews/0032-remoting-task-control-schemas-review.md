# Review 0032: Remoting task-control schemas

Date: 2026-08-24

Scope: decision 0025, the six locks under `schema/remoting/`, and their
schema-lock regression coverage. This review does not accept a generated
Remoting binding, task-start dispatcher, or transport implementation.

## Proposal review

Two independent reviews reported no P0. Their initial findings required:

- an explicit two-request-leg plus reply exchange rather than describing two
  independently enveloped payloads as one request message;
- bounded adjacency/join ownership and cleanup across partial network
  delivery;
- explicit no-retry, no-replay, and uncertain-outcome semantics;
- transactional task reference and control-endpoint publication;
- authorization of the accepted reply's newly claimed source endpoint;
- downstream ownership of generated Remoting adapters and no Wire dependency
  on Remoting;
- preservation of session-fatal malformed/noncanonical/invalid input;
- a concealed bounded rejection taxonomy;
- cancellation acceptance that does not claim task termination; and
- exclusion of local timeout, transport loss, peer unreachability, and inferred
  node death from peer lifecycle replies.

The revised decision uses strict adjacent request legs and retains at most one
incomplete pair on each configured ordered session ingress lane. It assigns
accepted initialization identities and maximum bytes per registered task-kind
pair, prohibits automatic retry, and makes the reply/source promotion one
transaction. The start reply has seven closed alternatives, cancellation two,
and observation four. A peer cannot report its own node-incarnation end.

## Fix review

The first narrow re-review reported P0/P1/P2 none. The second reported one P1
and two P2 wording gaps while confirming that all lock bytes were correct:

- codec/adapter `Invalid_Value` was ambiguous with a normal `Unavailable`
  reply;
- duplicate-ID wording could imply a session-wide receiver deduplication table;
- `Unknown_Completion` lacked a deterministic non-encoding disposition.

Decision 0025 now keeps every codec/adapter `Invalid_Value` peer input
session-fatal, including zero task-kind and task-reference identity values.
Only a successfully decoded valid value rejected later by a separately named
launch/admission policy may map to `Unavailable`. Pair validation rejects
equality of the adjacent messages' IDs, while session-wide nonreuse remains a
trusted-sender invariant. `Unknown_Completion` produces `Not_Available` before
codec invocation.

The mandatory narrow fix re-review reports:

- P0: none;
- P1: none;
- P2: none.

No finding is deferred.

## Verification

- Every lock validates through `tools/schema_lock.py`.
- Embedded fingerprints independently recompute to the decision table.
- Maximum encoded sizes independently recompute to
  `25 / 62 / 60 / 2 / 60 / 62`.
- All six family IDs and fingerprints are nonzero and mutually distinct;
  revision and profile are exactly one.
- Manual shape review matches all documented field, variant, and completion
  tags.
- `python3 tools/test_schema_lock.py`: 24 tests pass.
- `git diff --check`: clean.

The complete repository suite is presently blocked before build by the
unrelated staged Ada-generator migration's unavailable JSON dependency commit
`ed0ee23a92e5fcdece907836b260d4eb4498889b`. Focused lock validation does not
use that dependency. This review neither changes nor accepts that pending
migration.
