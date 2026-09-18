#!/bin/bash
set -euo pipefail
project_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$project_dir"

# Some Command Line Tools releases do not discover the bundled Testing macros.
# Tell the compiler where they live when that toolchain layout is present.
toolchain_bin="$(dirname "$(xcrun --find swiftc)")"
testing_plugins="$toolchain_bin/../lib/swift/host/plugins/testing"
if [[ -f "$testing_plugins/libTestingMacros.dylib" ]]; then
    swift test --disable-xctest -Xswiftc -plugin-path -Xswiftc "$testing_plugins" "$@"
else
    swift test --disable-xctest "$@"
fi
