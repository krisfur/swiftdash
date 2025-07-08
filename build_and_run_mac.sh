#!/bin/bash
#
# build_and_run_mac.sh
#
# This script builds and runs the macOS version of the SwiftDash game.
#
# Prerequisites:
#   - Xcode must be installed (from the App Store or https://developer.apple.com/xcode/)
#   - You must have the full Xcode command line tools set as active.
#
# To set up the command line tools:
#   1. Install Xcode from the App Store if you haven't already.
#   2. Run the following command in your terminal:
#
#      sudo xcode-select --switch /Applications/Xcode.app/Contents/Developer
#
#   3. You can verify with:
#
#      xcode-select --print-path
#      # Should output: /Applications/Xcode.app/Contents/Developer
#
# Usage:
#   ./build_and_run_mac.sh
#
# This will:
#   1. Build the macOS app using xcodebuild
#   2. Find the resulting .app bundle in DerivedData (the default Xcode build location)
#   3. Launch the app automatically

set -e

PROJECT="swiftdash.xcodeproj"
SCHEME="swiftdash macOS"
CONFIG="Debug"

# Build the macOS app
echo "Building $SCHEME..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration "$CONFIG" build

# Find the built app in DerivedData and copy it locally for easy access
echo "Finding built app in DerivedData..."
DERIVED_DATA_PATH="/Users/kfurman/Library/Developer/Xcode/DerivedData"
APP_PATH=$(find "$DERIVED_DATA_PATH" -name "swiftdash.app" -path "*/Build/Products/Debug/*" -not -path "*/Index.noindex/*" 2>/dev/null | head -1)

if [ -z "$APP_PATH" ] || [ ! -d "$APP_PATH" ]; then
    echo "Could not find swiftdash.app in DerivedData"
    echo "Build may have failed. Check the build output above."
    exit 1
fi

# Create local build directory and copy app there for easy access
echo "Copying app to local build directory for easy access..."
mkdir -p build/Debug
cp -R "$APP_PATH" build/Debug/
LOCAL_APP_PATH="build/Debug/swiftdash.app"

echo "App copied to: $LOCAL_APP_PATH"

echo "Found app: $APP_PATH"
echo "Running $LOCAL_APP_PATH..."
open "$LOCAL_APP_PATH" 