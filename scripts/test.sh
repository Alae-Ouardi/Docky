#!/usr/bin/env bash
# Runs the test suite. The explicit plugin path works around Command Line Tools
# installs where SwiftPM does not find the Swift Testing macro plugin on its own.
set -euo pipefail

cd "$(dirname "$0")/.."
source scripts/env.sh
PLUGINS="$(xcode-select -p)/usr/lib/swift/host/plugins/testing"
arch -arm64 swift test -Xswiftc -plugin-path -Xswiftc "$PLUGINS" "$@"
