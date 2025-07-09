#!/bin/bash

# Build and Run iOS Version of SwiftDash
# This script builds the iOS app and launches it in the iOS Simulator

set -e  # Exit on any error

echo "Building swiftdash iOS..."

# Build the iOS app
xcodebuild -project swiftdash.xcodeproj -scheme "swiftdash iOS" -configuration Debug build -destination 'platform=iOS Simulator,name=iPhone 16,OS=latest'

echo "Build completed successfully!"

# Find the built app in DerivedData and copy it locally for easy access
echo "Finding built app in DerivedData..."
APP_PATH="/Users/kfurman/Library/Developer/Xcode/DerivedData/swiftdash-edxowmetpetrybdjmapxqygnppqa/Build/Products/Debug-iphonesimulator/swiftdash.app"

if [ ! -d "$APP_PATH" ]; then
    echo "Error: Could not find swiftdash.app in DerivedData"
    echo "Build may have failed. Check the build output above."
    exit 1
fi

# Create local build directory and copy app there for easy access
echo "Copying app to local build directory for easy access..."
mkdir -p build/Debug-iphonesimulator
cp -R "$APP_PATH" build/Debug-iphonesimulator/
LOCAL_APP_PATH="build/Debug-iphonesimulator/swiftdash.app"

echo "App copied to: $LOCAL_APP_PATH"

echo "Found app: $APP_PATH"

# Get the simulator device to use
echo "Getting available iOS simulators..."
SIMULATORS=$(xcrun simctl list devices available | grep "iPhone" | grep -v "unavailable" | head -5)
echo "Available simulators:"
echo "$SIMULATORS"

# Use iPhone 16 if available, otherwise use the first available iPhone
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 16" | grep -v "unavailable" | head -1 | sed -E 's/.*\(([A-Z0-9-]+)\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
    echo "iPhone 16 not found, using first available iPhone..."
    DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | grep -v "unavailable" | head -1 | sed -E 's/.*\(([A-Z0-9-]+)\).*/\1/')
fi

if [ -z "$DEVICE_ID" ]; then
    echo "Error: No iOS simulators found. Please create one in Xcode."
    exit 1
fi

echo "Using simulator device: $DEVICE_ID"

# Boot the simulator if it's not already running
echo "Booting iOS simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true

    # Install the app
    echo "Installing app to simulator..."
    xcrun simctl install "$DEVICE_ID" "$LOCAL_APP_PATH"

# Launch the app
echo "Launching swiftdash in iOS Simulator..."
xcrun simctl launch "$DEVICE_ID" kfurman.swiftdash

# Open the simulator app to show the interface
echo "Opening iOS Simulator..."
open -a Simulator

# Give user instructions to manually rotate since simctl doesn't support rotation
echo "Please manually rotate the simulator to landscape orientation:"
echo "- Device → Rotate Left/Right from the Simulator menu"
echo "- The game is optimized for landscape mode"
sleep 1

echo "iOS version launched successfully!"
echo "The app should now be running in the iOS Simulator in landscape mode."
echo "You can interact with it using your mouse and keyboard."
echo ""
echo "Controls:"
echo "- Tap the screen to jump"
echo "- Tap the 'Menu' button in the top-left during gameplay to return to main menu"
echo "- Swipe from the left edge of the screen to go back (iOS back gesture)"