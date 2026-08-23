#!/bin/sh
set -eu

crate_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
log_file=$(mktemp "${TMPDIR:-/tmp}/flyology-wire-rejected.XXXXXX")
trap 'rm -f "$log_file"' EXIT HUP INT TERM

check_rejected() {
  project=$1
  diagnostic=$2
  if command -v alr >/dev/null 2>&1; then
    if alr -C "$crate_root/tests" exec -- gprbuild -q -p -P "$project" >"$log_file" 2>&1; then
      echo "expected generated binding rejection: $project" >&2
      return 1
    fi
  elif gprbuild -q -p -P "$project" >"$log_file" 2>&1; then
    echo "expected generated binding rejection: $project" >&2
    return 1
  fi
  if ! grep -F "$diagnostic" "$log_file" >/dev/null 2>&1; then
    echo "generated binding failed without the expected diagnostic: $diagnostic" >&2
    sed -n '1,160p' "$log_file" >&2
    return 1
  fi
}

check_rejected \
  "$crate_root/tests/rejected/sequence_capacity/rejected_sequence_capacity.gpr" \
  "Items capacity is below its wire-schema maximum"
check_rejected \
  "$crate_root/tests/rejected/sequence_lower_bound/rejected_sequence_lower_bound.gpr" \
  "Items lower bound differs from its wire construction bound"
check_rejected \
  "$crate_root/tests/rejected/bytes_capacity/rejected_bytes_capacity.gpr" \
  "Data capacity is below its wire-schema maximum"
check_rejected \
  "$crate_root/tests/rejected/bytes_lower_bound/rejected_bytes_lower_bound.gpr" \
  "Data lower bound differs from its wire construction bound"
