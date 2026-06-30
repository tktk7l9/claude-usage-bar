#!/usr/bin/env bash
# Builds a release binary and wraps it into a menu-bar-only .app bundle.
#
#   ./scripts/package-app.sh            # build into ./ClaudeUsageBar.app
#   ./scripts/package-app.sh --install  # also copy to /Applications
#
# Note: re-signing produces a new code identity, so the Keychain access dialog
# reappears on first launch after each rebuild. Choose "Always Allow". To make
# the identity stable, replace `--sign -` with your self-signed cert name (see
# README).
set -euo pipefail

cd "$(dirname "$0")/.."
APP_NAME="ClaudeUsageBar"
APP="${APP_NAME}.app"

echo "==> swift build -c release"
swift build -c release

BIN_PATH="$(swift build -c release --show-bin-path)/${APP_NAME}"
if [[ ! -x "$BIN_PATH" ]]; then
    echo "error: built binary not found at $BIN_PATH" >&2
    exit 1
fi

echo "==> assembling $APP"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_PATH" "$APP/Contents/MacOS/${APP_NAME}"
cp "Resources/Info.plist" "$APP/Contents/Info.plist"

echo "==> codesign (ad-hoc)"
codesign --force --deep --sign - "$APP"

echo "built: $(pwd)/$APP"

if [[ "${1:-}" == "--install" ]]; then
    echo "==> installing to /Applications"
    rm -rf "/Applications/$APP"
    cp -R "$APP" "/Applications/$APP"
    echo "installed: /Applications/$APP"
fi
