#!/bin/bash

set -e

echo "Building MITMMenuBar..."
swift build -c release

echo ""
echo "Creating app bundle..."

# Create app bundle structure
rm -rf MITMMenuBar.app
mkdir -p MITMMenuBar.app/Contents/MacOS
mkdir -p MITMMenuBar.app/Contents/Resources

# Copy binary
cp .build/release/MITMMenuBar MITMMenuBar.app/Contents/MacOS/

# Copy Info.plist
cp Sources/MITMMenuBar/Resources/Info.plist MITMMenuBar.app/Contents/

echo ""
echo "Build complete!"
echo ""
echo "App bundle created: MITMMenuBar.app"
echo ""
echo "To run:"
echo "  open MITMMenuBar.app"
echo ""
echo "To install to Applications:"
echo "  cp -r MITMMenuBar.app /Applications/"
