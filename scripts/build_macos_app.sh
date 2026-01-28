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
VENV_PREFIX="venv-"
VENV_DIR="${PROJECT_ROOT}/${VENV_PREFIX}dev"
FRONTEND_DIR="${PROJECT_ROOT}/frontend"
BUILD_DIR="${PROJECT_ROOT}/build"
DIST_DIR="${PROJECT_ROOT}/dist"
ICON_DIR="${BUILD_DIR}/icons"
SPEC_FILE="${PROJECT_ROOT}/SearchAPIWebUI.spec"

# Default architecture
ARCH="${1:-arm64}"  # arm64 or x86_64
if [[ "$ARCH" != "arm64" && "$ARCH" != "x86_64" ]]; then
    echo -e "${RED}Error: Unsupported architecture: $ARCH (use arm64 or x86_64)${NC}"
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

# Check dependencies
check_dependencies() {
    print_section "Checking Dependencies"

    local missing_deps=()

    if ! command_exists python3; then
        missing_deps+=("python3")
    fi

    if ! command_exists npm; then
        missing_deps+=("npm")
    fi

    if ! command_exists iconutil; then
        missing_deps+=("iconutil (part of macOS)")
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

# Setup or reuse virtual environment
setup_venv() {
    print_section "Setting Up Python Virtual Environment"

    if [ -d "$VENV_DIR" ]; then
        print_msg "$YELLOW" "Found existing venv at: $VENV_DIR"
        print_msg "$YELLOW" "Reusing existing virtual environment..."
    else
        print_msg "$BLUE" "Creating new virtual environment at: $VENV_DIR"
        python3 -m venv "$VENV_DIR"
        print_msg "$GREEN" "Virtual environment created"
    fi

    # Activate venv
    source "$VENV_DIR/bin/activate"

    # Upgrade pip
    print_msg "$BLUE" "Upgrading pip..."
    pip install --upgrade pip

    # Ensure frontend/dist directory exists for hatchling force-include
    if [ ! -d "${PROJECT_ROOT}/frontend/dist" ]; then
        print_msg "$BLUE" "Creating placeholder frontend/dist directory..."
        mkdir -p "${PROJECT_ROOT}/frontend/dist"
    fi

    # Install dependencies
    print_msg "$BLUE" "Installing Python dependencies..."
    pip install -e ".[webview,build]"

    print_msg "$GREEN" "Python environment ready"
}

# Build frontend
build_frontend() {
    print_section "Building Frontend"

    if [ ! -d "$FRONTEND_DIR" ]; then
        print_msg "$RED" "Error: Frontend directory not found at $FRONTEND_DIR"
        exit 1
    fi

    cd "$FRONTEND_DIR"

    # Always install npm dependencies to ensure platform-specific binaries are correct
    # This is especially important for rollup which has platform-specific native modules
    print_msg "$BLUE" "Installing npm dependencies..."
    npm install

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

# Verify icon exists
verify_icon() {
    print_section "Verifying App Icon"

    local icns_path="${PROJECT_ROOT}/frontend/public/AppIcon.icns"

    if [ ! -f "$icns_path" ]; then
        print_msg "$RED" "Error: Icon not found at $icns_path"
        exit 1
    fi

    print_msg "$GREEN" "Icon found at: $icns_path"
}

# Build app with PyInstaller
build_app() {
    print_section "Building macOS App with PyInstaller"

    print_msg "$BLUE" "Target architecture: $ARCH"

    # Clean previous build
    if [ -d "$BUILD_DIR/SearchAPIWebUI" ] || [ -d "$DIST_DIR/SearchAPIWebUI" ]; then
        print_msg "$YELLOW" "Cleaning previous build..."
        rm -rf "$BUILD_DIR/SearchAPIWebUI"
        rm -rf "$DIST_DIR/SearchAPIWebUI"
    fi

    # Modify spec file for target architecture
    if [ "$ARCH" = "x86_64" ]; then
        print_msg "$BLUE" "Updating spec file for x86_64..."
        sed -i.bak "s/target_arch='arm64'/target_arch='x86_64'/" "$SPEC_FILE"
    elif [ "$ARCH" = "arm64" ]; then
        print_msg "$BLUE" "Updating spec file for arm64..."
        sed -i.bak "s/target_arch='x86_64'/target_arch='arm64'/" "$SPEC_FILE"
    fi

    # Run PyInstaller
    print_msg "$BLUE" "Running PyInstaller..."
    pyinstaller --clean --noconfirm "$SPEC_FILE"

    # Restore spec file
    if [ -f "${SPEC_FILE}.bak" ]; then
        mv "${SPEC_FILE}.bak" "$SPEC_FILE"
    fi

    # Check if app was created
    local app_path="${DIST_DIR}/SearchAPIWebUI.app"
    if [ ! -d "$app_path" ]; then
        print_msg "$RED" "Error: App build failed - .app bundle not found"
        exit 1
    fi

    # Apply ad-hoc signature to allow running on user machines
    # This prevents Gatekeeper from blocking the app with "damaged" message
    print_msg "$BLUE" "Applying ad-hoc signature..."
    codesign --force --deep --sign - "$app_path"

    print_msg "$GREEN" "App built successfully at: $app_path"
}

# Create wrapper script to pass -w argument
create_wrapper() {
    print_section "Creating App Wrapper Script"

    local app_path="${DIST_DIR}/SearchAPIWebUI.app"
    local executable_path="${app_path}/Contents/MacOS/SearchAPIWebUI"
    local wrapper_path="${app_path}/Contents/MacOS/SearchAPIWebUI_wrapper"

    # Rename original executable
    mv "$executable_path" "$wrapper_path"

    # Create wrapper script
    cat > "$executable_path" << 'EOF'
#!/bin/bash
# Wrapper script to launch Search API WebUI in webview mode

# Get the directory where this script is located
DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Launch the actual executable with -w flag
exec "$DIR/SearchAPIWebUI_wrapper" -w "$@"
EOF

    # Make wrapper executable
    chmod +x "$executable_path"

    print_msg "$GREEN" "Wrapper script created successfully"
}

# Main build process
main() {
    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Search API WebUI - macOS App Builder"
    print_msg "$GREEN" "========================================="
    print_msg "$BLUE" "Architecture: $ARCH"
    echo ""

    check_dependencies
    setup_venv
    build_frontend
    verify_icon
    build_app
    create_wrapper

    print_section "Build Complete!"
    print_msg "$GREEN" "Your app is ready at:"
    print_msg "$GREEN" "  ${DIST_DIR}/SearchAPIWebUI.app"
    echo ""
    print_msg "$YELLOW" "Next steps:"
    print_msg "$YELLOW" "  1. Test the app: open ${DIST_DIR}/SearchAPIWebUI.app"
    print_msg "$YELLOW" "  2. Create DMG: ./scripts/create_dmg.sh"
    echo ""
}

# Run main
main
