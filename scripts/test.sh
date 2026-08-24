#!/bin/sh
set -eu

crate_root=$(CDPATH= cd -- "$(dirname -- "$0")/.." && pwd)
type_ir_root=${FLYOLOGY_TYPE_IR_ROOT:-}

if [ -z "$type_ir_root" ] || [ ! -d "$type_ir_root" ]; then
  echo "FLYOLOGY_TYPE_IR_ROOT must name the reviewed flyology-type-ir checkout" >&2
  exit 1
fi

"$crate_root/flyology_wire_generator/scripts/test.sh"

python3 "$crate_root/tools/test_schema_lock.py"
python3 "$crate_root/tools/test_schema_diff.py"
python3 "$crate_root/tools/test_generate_ada.py"
python3 "$crate_root/tools/test_type_ir_adapter.py"
python3 "$crate_root/tools/type_ir_adapter.py" \
  --fixture-shape \
  --check \
  "$type_ir_root" \
  "$type_ir_root/fixtures/wire-record-shape.json" \
  "$crate_root/schema/fixtures/wire-record-shape.overlay.json" \
  "$crate_root/schema/fixtures/profile-1-converted-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-converted-record.ada-binding.json" \
  "$crate_root/schema/fixtures/profile-1-converted-record.provenance.json"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  --compatible-writer \
  "$crate_root/schema/fixtures/profile-1-record-v1.lock.json" \
  "$crate_root/schema/fixtures/profile-1-v1-to-v2.approval.json" \
  --compatible-writer \
  "$crate_root/schema/fixtures/profile-1-record-v3.lock.json" \
  "$crate_root/schema/fixtures/profile-1-v3-to-v2.approval.json" \
  "$crate_root/schema/fixtures/profile-1-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-signed-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-signed-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-converted-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-converted-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-defaulted-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-defaulted-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-sequence-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-sequence-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-optional-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-optional-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-bytes-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-bytes-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-text-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-text-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-enumeration-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-enumeration-record.ada-binding.json" \
  "$crate_root/tests/generated"
python3 "$crate_root/tools/generate_ada.py" \
  --check \
  "$crate_root/schema/fixtures/profile-1-variant-record.lock.json" \
  "$crate_root/schema/fixtures/profile-1-variant-record.ada-binding.json" \
  "$crate_root/tests/generated"

if command -v alr >/dev/null 2>&1; then
  alr -C "$crate_root" build
  alr -C "$crate_root/tests" build
else
  gprbuild -q -p -P "$crate_root/flyology_wire.gpr"
  gprbuild -q -p -P "$crate_root/tests/flyology_wire_tests.gpr"
fi

"$crate_root/scripts/check-generated-binding-rejections.sh"

"$crate_root/tests/bin/wire_smoke"
"$crate_root/tests/bin/tagged_smoke"
"$crate_root/tests/bin/compatibility_smoke"
"$crate_root/tests/bin/profile_codec_smoke"
"$crate_root/tests/bin/generated_codec_smoke"
"$crate_root/tests/bin/generated_signed_codec_smoke"
"$crate_root/tests/bin/generated_converted_codec_smoke"
"$crate_root/tests/bin/generated_defaulted_codec_smoke"
"$crate_root/tests/bin/generated_sequence_codec_smoke"
"$crate_root/tests/bin/generated_optional_codec_smoke"
"$crate_root/tests/bin/generated_bytes_codec_smoke"
"$crate_root/tests/bin/generated_text_codec_smoke"
"$crate_root/tests/bin/generated_enumeration_codec_smoke"
"$crate_root/tests/bin/generated_variant_codec_smoke"
"$crate_root/tests/bin/borrowed_observer_smoke"
