#!/bin/sh
set -eu

crate_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)

if command -v alr >/dev/null 2>&1; then
  alr -C "$crate_root" build
  alr -C "$crate_root/tests" build
else
  gprbuild -q -p -P "$crate_root/flyology_wire.gpr"
  gprbuild -q -p -P "$crate_root/tests/flyology_wire_tests.gpr"
fi

"$crate_root/tests/bin/wire_smoke"
"$crate_root/tests/bin/tagged_smoke"
"$crate_root/tests/bin/compatibility_smoke"
"$crate_root/tests/bin/profile_codec_smoke"
"$crate_root/tests/bin/borrowed_observer_smoke"
