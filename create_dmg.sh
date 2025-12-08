#!/bin/bash

# Name of the app and scheme
APP_NAME="AirpodsMove"
DMG_NAME="AirShortcuts"
SCHEME="AirpodsMove"

echo "🚀 Building $APP_NAME in Release mode..."

# Build the app
DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer" xcodebuild -scheme "$SCHEME" \
           -configuration Release \
           -derivedDataPath build \
           -destination 'platform=macOS' \
           clean build

if [ $? -ne 0 ]; then
    echo "❌ Build failed."
    exit 1
fi

echo "✅ Build successful."

# Create a temporary directory for the DMG content
mkdir -p dist

# Copy the app to the dist folder
echo "📂 Copying app to distribution folder..."
cp -r "build/Build/Products/Release/$APP_NAME.app" dist/

# Create a symlink to Applications folder
ln -s /Applications dist/Applications

echo "📦 Creating DMG..."

# Create the DMG
hdiutil create -volname "$DMG_NAME" \
               -srcfolder dist \
               -ov -format UDZO \
               "$DMG_NAME.dmg"

if [ $? -ne 0 ]; then
    echo "❌ DMG creation failed."
    exit 1
fi

# Cleanup
echo "🧹 Cleaning up..."
rm -rf dist build

echo "🎉 DMG created successfully: $DMG_NAME.dmg"
