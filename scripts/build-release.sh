#!/bin/bash

# AskClaude Release Build Script
# Creates a release build ready for distribution

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/release-build"
APP_NAME="AskClaude"

echo "==================================="
echo "  AskClaude Release Builder"
echo "==================================="
echo ""

# Clean previous build
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "Building release..."

# Build the app using xcodebuild
cd "$PROJECT_DIR/AskClaude"
xcodebuild -project AskClaude.xcodeproj \
    -scheme AskClaude \
    -configuration Release \
    -derivedDataPath "$BUILD_DIR/DerivedData" \
    -archivePath "$BUILD_DIR/$APP_NAME.xcarchive" \
    archive \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Export the app from the archive
echo "Exporting app..."
cp -R "$BUILD_DIR/$APP_NAME.xcarchive/Products/Applications/$APP_NAME.app" "$BUILD_DIR/"

# Create zip for distribution
echo "Creating zip archive..."
cd "$BUILD_DIR"
zip -r "$APP_NAME.zip" "$APP_NAME.app"

# Get version from Info.plist if available
VERSION=$(defaults read "$BUILD_DIR/$APP_NAME.app/Contents/Info" CFBundleShortVersionString 2>/dev/null || echo "1.0.0")

echo ""
echo "==================================="
echo "  Build Complete!"
echo "==================================="
echo ""
echo "Output:"
echo "  App:     $BUILD_DIR/$APP_NAME.app"
echo "  Zip:     $BUILD_DIR/$APP_NAME.zip"
echo "  Version: $VERSION"
echo ""
echo "To create a GitHub release:"
echo "  1. Tag the release: git tag v$VERSION"
echo "  2. Push the tag: git push origin v$VERSION"
echo "  3. Create release on GitHub and attach $APP_NAME.zip"
echo ""
