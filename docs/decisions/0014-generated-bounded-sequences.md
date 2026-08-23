# Decision 0014: Generated bounded sequences use an explicit logical prefix

Status: accepted initial milestone

Date: 2026-08-23

## Context

Profile 1 carries one count for each sequence dimension and length-delimits
every element, while Ada arrays are definite objects with an index range rather
than a separate logical length. A varying bounded sequence therefore needs an
application representation that distinguishes allocated capacity from the
logical elements on the wire without allocation or an access value.

## Decision

The initial sequence backend accepts one-dimensional required sequences of
Boolean, signed 64-bit, or unsigned 64-bit elements. Its closed Ada binding
names two components in the root value:

- a definite Ada array supplying caller-owned capacity and element storage;
- an `Interfaces.Unsigned_64` component supplying the logical count.

The logical value is the first `Count` elements in Ada logical iteration order.
Unused capacity is not observed by measure or encode. Decode initializes unused
capacity to the element schema's lower value, fills the logical prefix, and
sets the count only in the unpublished candidate.

Generation rejects ranks other than one, unsupported element kinds, defaulted
sequence fields, duplicate component bindings, and source names outside its
closed grammar. Generated Ada binding checks require:

- array capacity at least the schema maximum count;
- the Ada array's first index equal the schema's explicit construction lower
  bound; and
- exact unsigned count and scalar element assignment compatibility.

The capacity and lower-bound checks are compile-time errors. Runtime measure
and decode independently enforce minimum/maximum counts and actual array
capacity before iteration.

Sequence value bytes are the shortest unsigned count followed by one
length-delimited canonical scalar for each logical element. The generated
helper measures this value with checked arithmetic. Root `Measure` adds the
field header, and `Encode` preflights the complete root before writing any
byte. Decode validates count, every element extent and scalar, exact element
count, and absence of trailing sequence bytes before publishing the candidate.

## Consequences

- Bounded varying sequences need no heap allocation, temporary element array,
  access value, or transport-specific representation.
- Ada index values do not appear on the wire, but the construction lower bound
  remains explicit and compile-time checked rather than guessed.
- Unused capacity is application storage, not part of equality at the wire
  layer; applications that include it in Ada record equality should initialize
  it to the generated construction value when comparing round trips.
- Multidimensional arrays, nested composite elements, optional sequences, and
  defaulted sequences require further binding and construction decisions;
  decision 0015 covers optional scalar fields only.
