# Shared build environment, sourced by the other scripts.
#
# Command Line Tools ship without SwiftUI's macro plugins, which the macOS 27 SDK needs
# for @State. When building without full Xcode, fall back to the bundled macOS 26 SDK.
DEVELOPER_DIR_PATH="$(xcode-select -p)"
if [[ -z "${SDKROOT:-}" && "$DEVELOPER_DIR_PATH" == *CommandLineTools* && -d "$DEVELOPER_DIR_PATH/SDKs/MacOSX26.sdk" ]]; then
    export SDKROOT="$DEVELOPER_DIR_PATH/SDKs/MacOSX26.sdk"
fi
