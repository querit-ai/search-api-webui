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

# Configuration
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
BUILDOZER_SPEC="${PROJECT_ROOT}/buildozer.spec"
BUILDOZER_SPEC_TEMP="${PROJECT_ROOT}/buildozer.spec.tmp"
PYPROJECT_TOML="${PROJECT_ROOT}/pyproject.toml"

# Build mode: debug or release
BUILD_MODE="${1:-debug}"  # debug or release
if [[ "$BUILD_MODE" != "debug" && "$BUILD_MODE" != "release" ]]; then
    echo -e "${RED}Error: Invalid build mode: $BUILD_MODE (use debug or release)${NC}"
    exit 1
fi

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

# Check if command exists
command_exists() {
    command -v "$1" >/dev/null 2>&1
}

# Cleanup temporary files
cleanup() {
    if [ -f "$BUILDOZER_SPEC_TEMP" ]; then
        print_msg "$YELLOW" "Cleaning up temporary buildozer.spec..."
        rm -f "$BUILDOZER_SPEC_TEMP"
    fi
}

# Set trap to cleanup on exit
trap cleanup EXIT

# Check dependencies
check_dependencies() {
    print_section "Checking Dependencies"

    local missing_deps=()

    if ! command_exists buildozer; then
        missing_deps+=("buildozer")
    fi

    if ! command_exists npm; then
        missing_deps+=("npm")
    fi

    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_msg "$RED" "Error: Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            print_msg "$RED" "  - $dep"
        done
        exit 1
    fi

    print_msg "$GREEN" "All dependencies found"
}

# Extract version from pyproject.toml
get_version() {
    print_section "Getting Version from pyproject.toml"

    if [ ! -f "$PYPROJECT_TOML" ]; then
        print_msg "$RED" "Error: pyproject.toml not found at $PYPROJECT_TOML"
        exit 1
    fi

    VERSION=$(grep -E '^version = ' "$PYPROJECT_TOML" | cut -d '"' -f 2)

    if [ -z "$VERSION" ]; then
        print_msg "$RED" "Error: Could not extract version from pyproject.toml"
        exit 1
    fi

    print_msg "$GREEN" "Version found: $VERSION"
}

# Prepare buildozer.spec with version substituted
prepare_buildozer_spec() {
    print_section "Preparing buildozer.spec with Version"

    # Replace __VERSION__ placeholder with actual version
    sed "s/__VERSION__/$VERSION/g" "$BUILDOZER_SPEC" > "$BUILDOZER_SPEC_TEMP"

    # For release builds, add signing configuration
    if [ "$BUILD_MODE" = "release" ] && [ -n "$ANDROID_KEYSTORE_PATH" ]; then
        print_msg "$BLUE" "Adding release signing configuration to buildozer.spec"

        # Verify keystore file exists
        if [ ! -f "$ANDROID_KEYSTORE_PATH" ]; then
            print_msg "$RED" "Error: Keystore file not found at: $ANDROID_KEYSTORE_PATH"
            exit 1
        fi

        print_msg "$GREEN" "Keystore verified: $ANDROID_KEYSTORE_PATH"
        print_msg "$BLUE" "Keystore alias: $ANDROID_KEY_ALIAS"

        # Append release signing configuration
        # Using android.* prefix with correct parameter names
        cat >> "$BUILDOZER_SPEC_TEMP" << EOF

# Release signing configuration (added by build script)
android.release_artifact = apk
android.accept_sdk_license = True

# Android release signing
android.sign = 1
android.keystore = $ANDROID_KEYSTORE_PATH
android.keyalias = $ANDROID_KEY_ALIAS
android.keystorepw = $ANDROID_KEYSTORE_PASSWORD
android.keyaliaspw = $ANDROID_KEY_PASSWORD
EOF

        print_msg "$GREEN" "Release signing configuration added to temporary buildozer.spec"
    fi

    # Verify the substitution
    BUILDOZER_VERSION=$(grep -E '^version = ' "$BUILDOZER_SPEC_TEMP" | awk '{print $3}')

    if [ "$BUILDOZER_VERSION" = "__VERSION__" ]; then
        print_msg "$RED" "Error: Version placeholder was not replaced"
        exit 1
    fi

    print_msg "$GREEN" "Created temporary buildozer.spec with version: $BUILDOZER_VERSION"
}

# Build frontend
build_frontend() {
    print_section "Building Frontend"

    if [ ! -d "$FRONTEND_DIR" ]; then
        print_msg "$RED" "Error: Frontend directory not found at $FRONTEND_DIR"
        exit 1
    fi

    cd "$FRONTEND_DIR"

    # Install npm dependencies if needed
    if [ ! -d "node_modules" ]; then
        print_msg "$BLUE" "Installing npm dependencies..."
        npm ci
    fi

    # Build frontend
    print_msg "$BLUE" "Building frontend assets..."
    npm run build

    if [ ! -d "dist" ]; then
        print_msg "$RED" "Error: Frontend build failed - dist directory not found"
        exit 1
    fi

    cd "$PROJECT_ROOT"
    print_msg "$GREEN" "Frontend built successfully"
}

# Check keystore for release builds
check_keystore() {
    if [ "$BUILD_MODE" = "release" ]; then
        print_section "Checking Keystore"

        # Support both local keystore file and environment variable path
        if [ -n "$ANDROID_KEYSTORE_PATH" ]; then
            # GitHub Actions: use keystore from environment variable
            keystore_file="$ANDROID_KEYSTORE_PATH"
            print_msg "$BLUE" "Using keystore from ANDROID_KEYSTORE_PATH: $keystore_file"
        else
            # Local build: use default keystore file
            keystore_file="${PROJECT_ROOT}/search-api-webui.keystore"
            print_msg "$BLUE" "Using local keystore: $keystore_file"
        fi

        if [ ! -f "$keystore_file" ]; then
            print_msg "$RED" "Error: Keystore file not found: $keystore_file"
            print_msg "$RED" "For local builds: create search-api-webui.keystore"
            print_msg "$RED" "For GitHub builds: ensure ANDROID_KEYSTORE_BASE64 secret is set"
            exit 1
        fi

        print_msg "$GREEN" "Keystore found at: $keystore_file"
    fi
}

# Build APK with buildozer
build_apk() {
    print_section "Building Android APK ($BUILD_MODE)"

    # Use the temporary spec file by setting environment variable or copying
    # Buildozer looks for buildozer.spec by default, so we temporarily rename
    mv "$BUILDOZER_SPEC" "${BUILDOZER_SPEC}.original"
    mv "$BUILDOZER_SPEC_TEMP" "$BUILDOZER_SPEC"

    # Export P4A_RELEASE_* environment variables for release builds
    if [ "$BUILD_MODE" = "release" ] && [ -n "$ANDROID_KEYSTORE_PATH" ]; then
        print_msg "$BLUE" "Exporting P4A_RELEASE_* environment variables..."
        export P4A_RELEASE_KEYSTORE="$ANDROID_KEYSTORE_PATH"
        export P4A_RELEASE_KEYALIAS="$ANDROID_KEY_ALIAS"
        export P4A_RELEASE_KEYSTORE_PASSWD="$ANDROID_KEYSTORE_PASSWORD"
        export P4A_RELEASE_KEYALIAS_PASSWD="$ANDROID_KEY_PASSWORD"

        print_msg "$GREEN" "P4A release environment variables set"
        print_msg "$BLUE" "P4A_RELEASE_KEYSTORE: $P4A_RELEASE_KEYSTORE"
        print_msg "$BLUE" "P4A_RELEASE_KEYALIAS: $P4A_RELEASE_KEYALIAS"
    fi

    # Build command
    local build_success=0
    if [ "$BUILD_MODE" = "release" ]; then
        print_msg "$BLUE" "Building release APK with signing..."
        if buildozer -v android release; then
            build_success=1
        fi
    else
        print_msg "$BLUE" "Building debug APK..."
        if buildozer -v android debug; then
            build_success=1
        fi
    fi

    # Restore original buildozer.spec
    mv "$BUILDOZER_SPEC" "$BUILDOZER_SPEC_TEMP"
    mv "${BUILDOZER_SPEC}.original" "$BUILDOZER_SPEC"

    if [ $build_success -eq 0 ]; then
        print_msg "$RED" "Error: Buildozer command failed"
        exit 1
    fi

    # Check if APK was created
    if [ ! -d "bin" ] || [ -z "$(ls -A bin/*.apk 2>/dev/null)" ]; then
        print_msg "$RED" "Error: APK build failed - no APK found in bin/"
        exit 1
    fi

    print_msg "$GREEN" "APK built successfully"
}

# Main build process
main() {
    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Search API WebUI - Android APK Builder"
    print_msg "$GREEN" "========================================="
    print_msg "$BLUE" "Build mode: $BUILD_MODE"
    echo ""

    check_dependencies
    get_version
    prepare_buildozer_spec
    build_frontend
    check_keystore
    build_apk

    print_section "Build Complete!"
    print_msg "$GREEN" "Your APK is ready at:"
    ls -lh bin/*.apk
    echo ""
}

# Run main
main
