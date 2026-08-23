# 0005: Borrowed observation uses a generated scoped visitor

Status: accepted for the first borrowed-observation implementation

## Context

Flyology's buffer API lends an `Ada.Streams.Stream_Element_Array` to a
synchronous callback. The formal array is not aliased, the callback must not
retain an address into it, and remoting owns the payload lease. Wire must not
weaken that lifetime contract or introduce an address overlay merely to expose
a convenient decoded view.

## Decision

The first zero-copy observation contract is a generated, statically bound
visitor. A generated `Validate_And_Visit` operation:

1. receives the writer schema and one complete borrowed payload;
2. validates the complete payload, canonical form, schema compatibility, and
   configured bounds before invoking application code;
3. makes a second bounded pass and invokes generated visitor callbacks for the
   logical value; and
4. returns before the caller's payload lease can be released.

Borrowed byte or text spans are passed only to the visitor callback that
observes them. Neither the visitor contract nor a generated field API returns a
view, access value, address, slice object with an input reference, or unchecked
pointer. Scalar callbacks receive copied values. Generated visitor bindings use
generic formal packages or subprograms rather than runtime class-wide dispatch.

The visitor is invoked only after successful whole-payload validation. A
malformed, noncanonical, incompatible, over-limit, or invalid payload invokes
no application callback and returns the normal codec status. An exception
raised by application visitor code propagates; wire does not misclassify it as
malformed input. Remoting retains the lease across normal return and exception
unwinding.

The caller keeps the input bytes stable from the start of validation through
the final callback return. Remoting satisfies this with its readable payload
lease. A direct caller must not retain a writable alias that application
visitor code can use to mutate the payload between the validation and
observation passes.

The ordinary `Decode` operation remains the construction contract. It builds
an unpublished candidate and commits only on success. Borrowed observation is
an additional generated capability, not a replacement codec abstraction in
remoting.

## Alternatives considered

### Freely returnable view

Rejected. Its lifetime would not be tied to remoting's lease, and ordinary Ada
assignment or storage could outlive the callback.

### Access-discriminated limited view

Deferred. Such a view can express useful accessibility relationships when the
source is explicitly aliased, but Flyology currently lends a non-aliased array.
Using `Unchecked_Access`, a native address, or an overlay would defeat the
safety objective. Requiring a different buffer API is not justified for v1.

### View containing offsets with input passed separately

Rejected for v1. An accessor could be called with a different same-sized input,
turning validation of one payload into trusted observation of another unless
it repeatedly revalidated identity and extents.

## Consequences

- Observation can avoid copying byte and text payloads under GNAT's supported
  callback convention without retaining their addresses.
- Whole-payload validation may perform two bounded passes. Benchmarks may later
  justify a reviewed single-pass design with a bounded generated offset table.
- A visitor cannot provide an arbitrarily retained random-access object.
- Unsafe application code can still violate Ada lifetime rules explicitly;
  wire does not attempt to make `Unchecked_Access` safe.
