#!/usr/bin/env bash
# Compile DXMT's .metal airconv shaders to .air and embed them as C headers.
# The DXMT meson flow does this via its metalir/hexdump generators; the iOS
# static-library flow consumes the headers directly, so this step reproduces
# that generation with the same compiler, flags, and xxd embedding.
set -euo pipefail
ROOT="${ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
SRC="$ROOT/dxmt/src/airconv/shaders"
OUT="$ROOT/build/dxmt-ios/shader-headers"
SHADERS=(air_msad air_samplepos air_tessellation)

# Ensure any previous modifications to shader files are cleanly reverted
git -C "$SRC" checkout -- . 2>/dev/null || true

for name in "${SHADERS[@]}"; do
  [[ -f "$SRC/$name.metal" ]] || { echo "ERROR: missing shader source $SRC/$name.metal (is the dxmt submodule checked out?)" >&2; exit 1; }
  echo "shader $name: compiling"
  mkdir -p "$OUT"

  # Compile shader; fallback to 5-arg only if compiler explicitly demands it
  if ! xcrun -sdk macosx metal -o "$OUT/$name.air" -c "$SRC/$name.metal" \
    -std=metal3.1 --target=air64-apple-macos14.0 2>/tmp/metal_err.log; then
    cat /tmp/metal_err.log
    if grep -q "expected 5" /tmp/metal_err.log && [[ "$name" == "air_tessellation" ]]; then
      echo "Compiler requires 5 arguments for __metal_atomic_fetch_add_explicit; applying patch..."
      sed -i.bak 's/__METAL_MEMORY_SCOPE_THREADGROUP__);/__METAL_MEMORY_SCOPE_THREADGROUP__, 0);/g' "$SRC/$name.metal"
      xcrun -sdk macosx metal -o "$OUT/$name.air" -c "$SRC/$name.metal" \
        -std=metal3.1 --target=air64-apple-macos14.0
    else
      cat /tmp/metal_err.log >&2
      exit 1
    fi
  fi
  xxd -n "$name" -i "$OUT/$name.air" "$OUT/$name.h"
done
