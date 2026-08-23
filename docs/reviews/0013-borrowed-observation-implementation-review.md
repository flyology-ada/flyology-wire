# Review 0013: Scoped borrowed observation implementation

Scope: decision 0005; generic extent lending, complete validation before
callbacks, two-pass observation, empty and invalid extents, payload stability,
exception behavior, and caller-storage identity.

Review date: 2026-08-23

## Findings and resolution

- P1: The first generated-style visitor formed an empty slice by subtracting
  one from a computed first index. That arithmetic was safe for the particular
  record field but was not a reusable contract at the index type's lower
  boundary. Profile 1 now provides a generic `Visit_Extent` lender that
  validates the extent, uses a fixed legal null range for empty values, and
  invokes no callback for an invalid extent.
- P1: A two-pass visitor requires the input bytes to remain stable after
  validation, but the accepted decision had not stated that caller obligation.
  Decision 0005 now makes stability through the final callback return explicit
  and ties it to remoting's readable payload lease.
- P2: Initial coverage demonstrated nonempty zero-copy observation but omitted
  an empty byte value, invalid and over-limit no-callback behavior,
  incompatible writers, and application exceptions. The smoke program now
  covers all of those paths and confirms that an application exception
  propagates rather than becoming a decode status.
- P2: The first build retained two ineffective use clauses and a mutable test
  value that never changed. They were removed or made constant; the strict
  build is warning-free.

No P0, P1, or P2 finding remains open for this slice.

## Verification after fixes

- GNATformat completed for the changed runtime and test Ada sources under
  their owning projects.
- The exact Flyology GNAT 16.2 Alire toolchain builds the library and all five
  smoke programs; all pass without compiler warnings.
- A direct GNAT 15.3 build and `borrowed_observer_smoke` run pass with strict
  warnings, validity checks, overflow checks, and the 110-column style limit.
- The low-level lender is tested with an empty extent on an array whose lower
  bound is `Stream_Element_Offset'First`, a nonempty arbitrary-bound extent,
  and an invalid extent that invokes no callback.
- The generated-style observer rejects malformed, incompatible, and
  over-limit input before application code. Successful validation is followed
  by a second pass; the byte callback sees the original payload address while
  executing, and no address or access value is returned or stored.
- The visitor and lender are statically bound generics. Runtime source remains
  pure, allocation-free, transport-independent, and free of remoting, Type IR,
  Libadalang, and serde dependencies.
