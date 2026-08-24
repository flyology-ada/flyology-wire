#!/bin/sh
set -eu

crate_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

alr -C "$crate_root" build
alr -C "$crate_root" build -- -U
alr -C "$crate_root" exec -- \
  gprbuild -q -p -XFLYOLOGY_WIRE_GENERATOR_TEST_HOOKS=enabled \
  -P "$crate_root/tests/flyology_wire_generator_tests.gpr"
"$crate_root/tests/bin/hashing_tests"
"$crate_root/tests/bin/flyology_wire_generator-wire_metadata_input_tests" "$crate_root/../schema"
"$crate_root/bin/flyology_wire_generate" --version
"$crate_root/bin/flyology_wire_generate" --help
"$crate_root/scripts/check-test-hook-elision.sh"
