#!/bin/bash

# AskClaude Installer
# Downloads and installs the latest release of AskClaude

set -e

REPO="andropar/AskClaude"
APP_NAME="AskClaude.app"
INSTALL_DIR="/Applications"

echo "==================================="
echo "  AskClaude Installer"
echo "==================================="
echo ""

# Check for macOS
if [[ "$(uname)" != "Darwin" ]]; then
    echo "Error: AskClaude only runs on macOS"
    exit 1
fi

# Check macOS version (requires 14.0+)
macos_version=$(sw_vers -productVersion)
major_version=$(echo "$macos_version" | cut -d. -f1)
if [[ "$major_version" -lt 14 ]]; then
    echo "Error: AskClaude requires macOS 14.0 or later (you have $macos_version)"
    exit 1
fi

echo "Downloading AskClaude..."

# Get the latest release URL
LATEST_RELEASE=$(curl -sL "https://api.github.com/repos/$REPO/releases/latest" | grep '"browser_download_url".*\.zip"' | head -1 | cut -d'"' -f4)

if [[ -z "$LATEST_RELEASE" ]]; then
    echo "Error: Could not find latest release. Please download manually from:"
    echo "  https://github.com/$REPO/releases"
    exit 1
fi

# Create temp directory
TEMP_DIR=$(mktemp -d)
trap "rm -rf $TEMP_DIR" EXIT

# Download
curl -sL "$LATEST_RELEASE" -o "$TEMP_DIR/AskClaude.zip"

echo "Extracting..."
unzip -q "$TEMP_DIR/AskClaude.zip" -d "$TEMP_DIR"

# Remove old version if exists
if [[ -d "$INSTALL_DIR/$APP_NAME" ]]; then
    echo "Removing previous version..."
    rm -rf "$INSTALL_DIR/$APP_NAME"
fi

# Move to Applications
echo "Installing to $INSTALL_DIR..."
mv "$TEMP_DIR/$APP_NAME" "$INSTALL_DIR/"

# Remove quarantine attribute (bypass Gatekeeper warning)
xattr -rd com.apple.quarantine "$INSTALL_DIR/$APP_NAME" 2>/dev/null || true

# Enable the Finder extension
echo "Enabling Finder extension..."
pluginkit -e use -i com.askclaude.app.FinderSyncExtension 2>/dev/null || true

echo ""
echo "==================================="
echo "  Installation Complete!"
echo "==================================="
echo ""
echo "AskClaude has been installed to /Applications"
echo ""
echo "To use:"
echo "  1. Open AskClaude from /Applications (first time only)"
echo "  2. Right-click any folder in Finder"
echo "  3. Click 'Ask Claude'"
echo ""
echo "Note: If the Finder extension doesn't appear, you may need to:"
echo "  - Go to System Settings > Privacy & Security > Extensions > Finder"
echo "  - Enable 'AskClaude'"
echo ""

# Open the app
echo "Opening AskClaude..."
open "$INSTALL_DIR/$APP_NAME"
