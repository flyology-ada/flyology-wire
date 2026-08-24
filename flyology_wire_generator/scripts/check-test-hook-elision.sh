#!/bin/sh
set -eu

crate_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
sentinel=flyology_wire_generator_disabled_consume_parser_release_failure

check_profile() {
  profile=$1
  shift

  alr -C "$crate_root" -n build "$@" -- -U -XFLYOLOGY_WIRE_GENERATOR_TEST_HOOKS=disabled
  object="$crate_root/obj/$profile/disabled/flyology_wire_generator-wire_metadata_input.o"
  test -f "$object"
  if nm "$object" | grep -q "$sentinel"; then
    echo "disabled parser-release test hook survived the $profile build" >&2
    exit 1
  fi
}

check_profile development
check_profile release --release
