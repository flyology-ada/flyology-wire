# Flyology Wire

`flyology_wire` defines bounded, transport-independent wire identities and
statically bound Ada codec contracts. Codecs measure and encode into
caller-owned `Ada.Streams.Stream_Element_Array` storage and report malformed or
incompatible input through status values. Decode receives the writer's schema
identity explicitly so compatibility is not inferred from payload bytes. The
shared size helpers make composed exact measurement overflow-safe. The crate
performs no I/O and has no dependency on Flyology or remoting.

The current milestone contains the minimum runtime surface needed by
`flyology_remoting`. Canonical payload profiles, schema derivation, compatibility
tooling, and generated codecs will be added separately. Libadalang is a
build-tool dependency of the planned shared `flyology_type_ir` extractor, not a
runtime dependency of this crate.

GNAT 16 is the primary development toolchain. The declared Alire dependency
also permits GNAT 13 through 15 so compatibility can be checked without making
an older compiler authoritative.

Build the library and its nested test crate with:

```sh
alr build
alr -C tests build
tests/bin/wire_smoke
```

Architecture and implementation changes follow the mandatory review cycle in
[`CONTRIBUTING.md`](CONTRIBUTING.md). The initial runtime boundary is recorded
in [`docs/decisions/0001-runtime-boundary.md`](docs/decisions/0001-runtime-boundary.md).
The corresponding review record is under [`docs/reviews/`](docs/reviews/).
