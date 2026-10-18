#!/bin/zsh
set -eu
setopt pipefail
cd -- "${0:A:h}"
METER_MIN_MACOS_VERSION="$(< MACOS_MIN_VERSION)"
mkdir -p build/tests
METER_CACHE="${TMPDIR:-/tmp}/codex-meter-module-cache"
CLANG_MODULE_CACHE_PATH="$METER_CACHE" swiftc -swift-version 5 -module-cache-path "$METER_CACHE" \
    -target "arm64-apple-macos$METER_MIN_MACOS_VERSION" -Onone \
    src/Models.swift src/RecoveryEvents.swift src/RingState.swift tests/main.swift \
    -o build/tests/CodexMeterTests
build/tests/CodexMeterTests
