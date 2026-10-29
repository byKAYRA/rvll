#!/bin/bash
# Build libmadeira_rppairing.a (on-device remote pairing for Built-in StikJIT,
# app/Madeira/JITPairing.swift) for iOS arm64 and copy it to app/Madeira/,
# where the app target links it. The C interface is app/Madeira/MadeiraRPPairing.h.
#
# Dependencies come from crates.io at the versions in Cargo.lock (idevice is
# MIT, jkcoxson/idevice; see THIRD-PARTY-NOTICES.md). Their licence notices
# are regenerated into app/Madeira/legal/LICENSES-rppairing-crates.txt, which
# the app bundles. Needs rustup with the aarch64-apple-ios target
# (`rustup target add aarch64-apple-ios`) and python3.
set -euo pipefail

BUILD_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$BUILD_DIR/../.." && pwd)"
TARGET=aarch64-apple-ios
export IPHONEOS_DEPLOYMENT_TARGET=17.0

if [[ "${GITHUB_ACTIONS:-}" == true && -s "$REPO_ROOT/app/Madeira/libmadeira_rppairing.a" &&
      -s "$REPO_ROOT/app/Madeira/legal/LICENSES-rppairing-crates.txt" ]]; then
    echo "Using the input-matched pairing iOS cache"
    exit 0
fi

cd "$BUILD_DIR"

if ! command -v rustup >/dev/null 2>&1; then
    if [[ -f "$HOME/.cargo/env" ]]; then
        source "$HOME/.cargo/env"
    fi
fi
if ! command -v rustup >/dev/null 2>&1; then
    echo "Installing rustup..."
    curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
    source "$HOME/.cargo/env"
fi

rustup target add "$TARGET"
cargo build --release --locked --target "$TARGET"
cp "target/$TARGET/release/libmadeira_rppairing.a" "$REPO_ROOT/app/Madeira/libmadeira_rppairing.a"
echo "-> app/Madeira/libmadeira_rppairing.a"
mkdir -p "$REPO_ROOT/app/Madeira/legal"
python3 "$BUILD_DIR/notices.py" "$REPO_ROOT/app/Madeira/legal/LICENSES-rppairing-crates.txt"
