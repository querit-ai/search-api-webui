#!/bin/bash

set -e  # Exit on error

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Get script directory and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Get architecture parameter (default to arm64)
ARCH="${1:-arm64}"

# Get version from pyproject.toml
VERSION=$(grep '^version = ' "${PROJECT_ROOT}/pyproject.toml" | sed 's/version = "\(.*\)"/\1/')

# Configuration
APP_NAME="SearchAPIWebUI"
APP_PATH="${PROJECT_ROOT}/dist/${APP_NAME}.app"
DMG_NAME="${APP_NAME}-${VERSION}-macOS-${ARCH}"
DMG_PATH="${PROJECT_ROOT}/dist/${DMG_NAME}.dmg"
TEMP_DMG="${PROJECT_ROOT}/dist/temp-${ARCH}.dmg"
VOLUME_NAME="Search API WebUI"
VOLUME_ICON_PATH="${PROJECT_ROOT}/build/icons/icon.icns"

# Print colored message
print_msg() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Print section header
print_section() {
    echo ""
    print_msg "$BLUE" "========================================"
    print_msg "$BLUE" "$1"
    print_msg "$BLUE" "========================================"
}

# Check if app exists
check_app() {
    print_section "Checking for App Bundle (${ARCH})"

    if [ ! -d "$APP_PATH" ]; then
        print_msg "$RED" "Error: App bundle not found at $APP_PATH"
        print_msg "$RED" "Please run ./scripts/build_macos_app.sh ${ARCH} first"
        exit 1
    fi

    print_msg "$GREEN" "App bundle found: $APP_PATH"
    print_msg "$BLUE" "Architecture: ${ARCH}"
}

# Calculate app size
calculate_size() {
    local size=$(du -sm "$APP_PATH" | awk '{print $1}')
    # Add 50MB buffer for DMG overhead
    local dmg_size=$((size + 50))
    echo "$dmg_size"
}

# Create DMG
create_dmg() {
    print_section "Creating DMG Package"

    # Remove old DMG if exists
    if [ -f "$DMG_PATH" ]; then
        print_msg "$YELLOW" "Removing old DMG..."
        rm -f "$DMG_PATH"
    fi

    if [ -f "$TEMP_DMG" ]; then
        rm -f "$TEMP_DMG"
    fi

    # Calculate size
    local dmg_size=$(calculate_size)
    print_msg "$BLUE" "DMG size: ${dmg_size}MB"

    # Create temporary DMG
    print_msg "$BLUE" "Creating temporary DMG..."
    hdiutil create -size "${dmg_size}m" -fs HFS+ -volname "$VOLUME_NAME" "$TEMP_DMG"

    # Mount temporary DMG
    print_msg "$BLUE" "Mounting temporary DMG..."
    local attach_output
    attach_output=$(hdiutil attach "$TEMP_DMG" -readwrite -noverify -noautoopen -nobrowse)
    local device
    device=$(echo "$attach_output" | awk '/\/Volumes\// {print $1; exit}')
    local mount_point
    mount_point=$(echo "$attach_output" | grep -o '/Volumes/.*' | head -n1)

    print_msg "$GREEN" "Mounted at: $mount_point"

    # Copy app to DMG
    print_msg "$BLUE" "Copying app to DMG..."
    cp -R "$APP_PATH" "$mount_point/"

    # Create Applications symlink
    print_msg "$BLUE" "Creating Applications symlink..."
    if [ ! -e "$mount_point/Applications" ]; then
        ln -s /Applications "$mount_point/Applications"
    else
        print_msg "$YELLOW" "Applications symlink already exists, skipping..."
    fi

    # Set custom icon if available
    if [ -f "$VOLUME_ICON_PATH" ]; then
        print_msg "$BLUE" "Setting custom volume icon..."
        cp "$VOLUME_ICON_PATH" "$mount_point/.VolumeIcon.icns"
        SetFile -a C "$mount_point"
    fi

    # Create .DS_Store for custom layout
    print_msg "$BLUE" "Creating custom layout..."
    create_ds_store "$mount_point"

    # Unmount
    print_msg "$BLUE" "Unmounting DMG..."
    hdiutil detach "$device"

    # Convert to compressed DMG
    print_msg "$BLUE" "Compressing DMG..."
    hdiutil convert "$TEMP_DMG" -format UDZO -o "$DMG_PATH"

    # Remove temporary DMG
    rm -f "$TEMP_DMG"

    print_msg "$GREEN" "DMG created successfully: $DMG_PATH"
}

# Create .DS_Store for custom layout
create_ds_store() {
    local mount_point=$1

    # Use osascript to set up the DMG window in background
    # Run with error handling but suppress window display
    osascript <<EOF 2>&1 | grep -v "^$" || true
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set the bounds of container window to {100, 100, 600, 400}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 96
        set position of item "${APP_NAME}.app" of container window to {120, 150}
        set position of item "Applications" of container window to {380, 150}
        close
        update without registering applications
        delay 1
    end tell
end tell
EOF

    print_msg "$GREEN" "Custom layout applied"
}

# Get DMG info
get_dmg_info() {
    print_section "DMG Information"

    local dmg_size=$(du -h "$DMG_PATH" | awk '{print $1}')

    print_msg "$GREEN" "DMG Name: ${DMG_NAME}.dmg"
    print_msg "$GREEN" "DMG Size: $dmg_size"
    print_msg "$GREEN" "Location: $DMG_PATH"
}

# Main process
main() {
    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Search API WebUI - DMG Creator"
    print_msg "$GREEN" "========================================="
    print_msg "$BLUE" "Version: ${VERSION}"
    print_msg "$BLUE" "Architecture: ${ARCH}"
    echo ""

    check_app
    create_dmg
    get_dmg_info

    print_section "DMG Creation Complete!"
    print_msg "$GREEN" "Your DMG is ready at:"
    print_msg "$GREEN" "  $DMG_PATH"
    echo ""
    print_msg "$YELLOW" "To test the DMG:"
    print_msg "$YELLOW" "  1. Double-click to mount: $DMG_PATH"
    print_msg "$YELLOW" "  2. Drag ${APP_NAME}.app to Applications"
    print_msg "$YELLOW" "  3. Launch from Applications folder"
    echo ""
}

# Run main
main
