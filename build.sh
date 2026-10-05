#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")"
APP_PATH="${1:-/Applications/MITMMenuBar.app}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/mitmmenubar-build.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "Building MITMMenuBar..."
swift build -c release

echo ""
echo "Creating app bundle..."

# Assemble outside the project so Spotlight only sees the installed copy.
STAGED_APP="$STAGING_DIR/MITMMenuBar.app"
mkdir -p "$STAGED_APP/Contents/MacOS"
mkdir -p "$STAGED_APP/Contents/Resources"

# Copy binary
cp .build/release/MITMMenuBar "$STAGED_APP/Contents/MacOS/"

# Copy Info.plist
cp Sources/MITMMenuBar/Resources/Info.plist "$STAGED_APP/Contents/"
cp Sources/MITMMenuBar/Resources/AppIcon.icns "$STAGED_APP/Contents/Resources/"

# Sign after adding the icon and bundle metadata.
codesign --force --sign - "$STAGED_APP"

echo "Installing to $APP_PATH..."
ditto "$STAGED_APP" "$APP_PATH"
codesign --verify --strict "$APP_PATH"

echo ""
echo "Build complete!"
echo ""
echo "App installed: $APP_PATH"
echo ""
echo "To run:"
echo "  open \"$APP_PATH\""
