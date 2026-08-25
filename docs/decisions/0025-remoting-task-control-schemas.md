# 0025: Profile 1 remoting task-control schemas

Status: accepted on 2026-08-24

## Context

Flyology Remoting starts only an exact registered `(Task_Kind_ID,
Task_Kind_Version)` pair. The start operation also carries one application
initialization value whose canonical bytes and writer `Schema_Identity` must
remain unchanged across in-process, IPC, and network delivery. A successful
start publishes an exact `Task_Reference` and a control endpoint. Cancellation
and observation must not turn a caller timeout or transport failure into a
peer lifecycle fact.

The version-one remoting envelope has one payload extent and one writer
`Schema_Identity`. Nesting arbitrary initialization bytes in a generated start
record would either copy the bytes or require a second segmented-codec runtime
contract. Appending an independently typed segment to a complete Profile 1
payload would make the envelope identity untrue. Expanding the fixed 144-byte
envelope would break the accepted remoting boundary.

## Decision

Wire assigns six separate Profile 1 families. Each begins at schema revision
1 and has no compatibility edge. The committed schema locks are authoritative
for the tags and bounds below.

| Family | Family ID | Schema fingerprint | Maximum bytes |
| --- | --- | --- | ---: |
| Task start request | `df93dd4004b84d399006e8b620185805` | `b79276125f1ff1d462df0430b47b120c5f69ab7b5b3ce12530560094b37cf388` | 25 |
| Task start reply | `97d8fd939a27410dbf88b6dc74c01db9` | `9eb3288b46e957c5ea3fe0e6fec332b7963e3cad8539de1f8a4f06b7a43c6c0e` | 62 |
| Task cancel request | `07bdef65f3d440afbb7674e51fdaf48b` | `3d71a4dba039d599d40b666740d003677995fb91bf1bd06017e8598382193c5e` | 60 |
| Task cancel reply | `cc8b4d25bc3c4d3dbd51e3bedc808bbb` | `ee4b58090ca76a3219742a27d311965629b247d362d42a1cbde75b6f62d1bcd6` | 2 |
| Task observe request | `11cb32c5a8fa41659d55b3ba1d6bd57a` | `654cf718fbeac6202bd569d8ac2f9223f74447f16495dcbd3e4e7ef0d87f2ab5` | 60 |
| Task observe reply | `b7eb038023b449328e9216be626d4343` | `0c3358690393e5caba8a8ae4d4a6441acaf99ddfc634f11429fe9953adb8576d` | 62 |

All six use `Profile_ID = 1`. These family IDs identify control-message
schemas. They do not become values or constants in the `flyology_wire`
runtime identity API, and `Task_Kind_ID` remains a Remoting value.

### Start pair

One high-level Remoting start attempt is a three-message exchange. Its request
has two ordinary version-one enveloped legs in strict adjacency, followed by
one correlated reply:

1. a task-start request carrying the generated 25-byte-bounded control value;
2. the application initialization payload, unchanged, whose own envelope
   carries its actual writer `Schema_Identity`;
3. one task-start reply correlated to the control request.

The start request has no correlation. The initialization message has its own
nonzero message ID and correlates to the start request's message ID. Both
messages have the same exact session binding and source and destination
endpoint references. The control message occurs first. No unrelated frame may
interleave the pair.

A local start submission reserves all required builder, header, queue, and
payload ownership for both request legs before committing either one. The
local transport submission publishes the pair as one ordered queue item. A
network can still fail between the two frames, so the receiving session
retains at most one incomplete adjacent pair on each ordered ingress lane and
delivers nothing to the task-start service until both complete. This is the
entire pending-start join bound: one control header and at most 25 control
payload octets, plus one ordinary session-bounded in-progress initialization
frame, per ingress lane. It introduces no correlation table. Another frame
where the initialization frame is required is a protocol violation.
Session/path close, frame failure, or ingress cancellation releases the
retained control frame and initialization lease. An idle peer can retain only
its session's one ingress lane, like an incomplete frame; session liveness and
close policy, rather than a wire deadline, bound that condition.

The pair is validated under the exact session binding, source endpoint,
destination endpoint, and start message ID. Reversed, nonadjacent,
cross-endpoint, uncorrelated, multiply correlated, equal start and
initialization message IDs, and stray initialization messages are rejected
deterministically. Session-wide message-ID nonreuse remains the trusted-sender
invariant from the envelope decision; this protocol adds no receiver
deduplication table. No pair creates a task until both complete envelopes and
payload extents are valid.

Every registered task-kind pair binds the accepted initialization writer
identities or directional compatibility edges, a maximum initialization byte
extent no greater than the session limit, and its application constructor.
Those are catalogue/deployment policy and do not alter either control lock.

There is no implicit or automatic retry, replay, or exactly-once start. One
message ID identifies only one attempt in one live session and is never reused
there; reconnect does not replay a pair. Loss of an accepted reply leaves the
caller with an uncertain outcome. Retrying under a new message ID can create
another task and requires an application idempotency design.

### Start request

The root record fields are:

| Field tag | Meaning |
| ---: | --- |
| 1 | `Task_Kind_ID`, exactly 16 octets in its semantic index order |
| 2 | `Task_Kind_Version`, unsigned `1 .. 2**32 - 1` |

The all-zero task-kind ID is rejected by the Remoting adapter before encode
and after decode. On peer input this is codec/adapter `Invalid_Value` and is
session-fatal, not a normal unavailable reply. The lock does not derive the ID
from a Wire family, Ada type, name, source location, or representation clause.

### Task reference value

Start acceptance, cancel requests, observe requests, and replacement facts use
the same logical `Task_Reference` fields:

| Field tag | Meaning |
| ---: | --- |
| 1 | stable `Node_ID`, 16 octets: high unsigned word then low unsigned word, each big-endian |
| 2 | `Incarnation_ID`, encoded by the same 16-octet rule |
| 3 | nonzero unsigned 64-bit `Task_ID` |
| 4 | nonzero unsigned 64-bit task generation |

The Remoting adapter validates both 128-bit identities as nonzero logical
values. A zero identity or other invalid task reference is codec/adapter
`Invalid_Value` and retains the session-fatal peer-input classification. This
encoding is independent of the Ada private-type and record layouts.

### Start outcome

The root variant tags are:

| Variant tag | Meaning |
| ---: | --- |
| 1 | `Accepted`, with the exact task-reference fields |
| 2 | `Unavailable`, concealing unknown kind versus unsupported version |
| 3 | `Unknown_Task_Kind`, only when the authenticated-session disclosure policy permits it |
| 4 | `Unsupported_Task_Kind_Version`, under the same policy |
| 5 | `Authorization_Rejected` |
| 6 | `Admission_Unavailable`, after exact lookup and authorization |
| 7 | `Launch_Failed_Before_Publication` |

An accepted response is emitted only after catalogue lookup, authorization,
initialization schema and extent acceptance, canonical initialization decode
and application validation, task-reference allocation, task launch commit,
and control-endpoint publication. Malformed, noncanonical, configured-limit
exceeding, or codec/adapter `Invalid_Value` peer input retains the existing
session-fatal ingress classification and is not a normal start reply. An
otherwise valid but unaccepted initialization writer maps to `Unavailable`
rather than exposing catalogue policy. A successfully decoded and valid
initialization value rejected afterward by a separately named launch or
admission policy can likewise map to `Unavailable`; that policy rejection is
not codec validation.

An accepted reply's envelope source endpoint is the exact published control
endpoint. Pending-request state explicitly permits this one correlated reply
to come from a newly claimed endpoint on the same authenticated peer node. It
promotes that endpoint only after the `Accepted` task-reference node equals
the reply-source node and every transactional check succeeds. Remoting retains
the endpoint and lifecycle record through immediate task exit and response
admission. A rejected response comes from the task-start service endpoint.
Correlation with the start request and both endpoint references remain
Remoting envelope metadata, not Wire payload fields.

### Cancellation

A cancel request carries the exact task-reference fields and is sent to the
published control endpoint. Cancel-outcome variant tags are:

| Variant tag | Meaning |
| ---: | --- |
| 1 | `Cancellation_Requested`: the destination accepted the request |
| 2 | `Not_Applied`, folding stale, terminal, policy, and reference-mismatch causes |

`Cancellation_Requested` never means the task has ended. Termination is
learned only from a lifecycle fact.

### Observation

An observe request carries the exact task-reference fields and is sent to the
control endpoint. Observe-reply variant tags are:

| Variant tag | Meaning |
| ---: | --- |
| 1 | `Still_Current`, a snapshot fact at the destination |
| 2 | `Task_Ended`, with one completion-kind enumeration |
| 3 | `Task_Replaced`, with the replacement task-reference fields |
| 4 | `Not_Available`, meaning the destination cannot supply the requested retained fact |

Completion-kind tags 1 through 12 respectively mean `Normal_Return`,
`Unhandled_Exception`, `Cancelled`, `Supervisor_Shutdown`,
`Abnormal_Completion`, `Activation_Failure`, `Readiness_Timeout`,
`Restart_Requested`, `Unhealthy`, `Stop_Timeout`, `Stuck`, and
`Policy_Exhaustion`. The local `Unknown_Completion` sentinel is not encodable.
An otherwise valid retained observation carrying that sentinel produces the
`Not_Available` reply instead of invoking the codec with an invalid enum.
Diagnostic strings are omitted from this minimum schema; adding them requires
a later bounded text and disclosure policy.

No wire reply represents `Observation_Timed_Out`, `Peer_Unreachable`,
`Node_Incarnation_Ended`, a local operation cancellation, or
transport/session loss. Those remain local Remoting API outcomes. In
particular, a dead node cannot report its own end. Remoting may publish
`Node_Incarnation_Ended` locally only from an authorized process-liveness
source, never by decoding a peer reply or inferring it from a disconnect.

## Runtime and generation boundary

This decision changes no `flyology_wire` runtime package, codec contract, or
identity type. Both messages in a start pair remain ordinary contiguous
payloads encoded through the existing caller-buffer contract. Pair ownership,
correlation, adjacency, envelope construction, and control-endpoint routing
belong to Remoting.

The current generator backend does not yet lower every private Remoting value
adapter and composite variant used by these locks. Generated bindings belong
in Remoting or a protocol crate that depends on `flyology_wire`; Wire never
depends on Remoting. Generated bindings or reviewed handwritten adapters must
satisfy the existing static codec contract before Remoting assigns protocol
bytes. The locks alone do not authorize a task-start implementation.

## Consequences

- Initialization bytes retain their actual application family and exact
  writer identity and move by lease without an encode-copy into a control
  value.
- The 144-byte envelope and Wire runtime stay unchanged.
- Strict adjacency avoids an unbounded pending-start correlation table.
- Separate semantic families prevent a request codec from accepting a reply
  or a cancellation message merely because their shapes overlap.
- Local delivery failures cannot be mistaken for destination lifecycle facts.

## Alternatives

- Nest initialization bytes and their writer identity in one Profile 1 record.
  This requires copying or a new segmented-codec contract and gives the outer
  envelope only the control schema identity.
- Append an opaque segment to a complete control payload. The envelope identity
  would not describe the complete payload and trailing bytes would violate
  Profile 1.
- Expand the remoting envelope to carry two schema identities. This breaks the
  fixed version-one envelope and duplicates composition policy in transport.
- Use one variant family for all control messages. Separate families provide a
  narrower decoder boundary and independent evolution.
