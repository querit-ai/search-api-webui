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
SPEC_FILE="${PROJECT_ROOT}/SearchAPIWebUI.spec"

# Default architecture
ARCH="${1:-x64}"  # x64 or x86
if [[ "$ARCH" != "x64" && "$ARCH" != "x86" ]]; then
    echo -e "${RED}Error: Unsupported architecture: $ARCH (use x64 or x86)${NC}"
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

    # Activate venv (Windows-style in Git Bash or similar)
    if [ -f "$VENV_DIR/Scripts/activate" ]; then
        source "$VENV_DIR/Scripts/activate"
        PYTHON_BIN="$VENV_DIR/Scripts/python"
        PIP_BIN="$VENV_DIR/Scripts/pip"
    else
        source "$VENV_DIR/bin/activate"
        PYTHON_BIN="$VENV_DIR/bin/python3"
        PIP_BIN="$VENV_DIR/bin/pip"
    fi

    # Upgrade pip using the recommended method (allow failure)
    print_msg "$BLUE" "Upgrading pip..."
    set +e  # Temporarily disable exit on error
    "$PYTHON_BIN" -m pip install --upgrade pip
    PIP_EXIT_CODE=$?
    set -e  # Re-enable exit on error

    if [ $PIP_EXIT_CODE -ne 0 ]; then
        print_msg "$YELLOW" "Warning: pip upgrade failed (exit code: $PIP_EXIT_CODE), continuing with existing version"
    else
        print_msg "$GREEN" "pip upgraded successfully"
    fi

    # Ensure frontend/dist directory exists for hatchling force-include
    if [ ! -d "${PROJECT_ROOT}/frontend/dist" ]; then
        print_msg "$BLUE" "Creating placeholder frontend/dist directory..."
        mkdir -p "${PROJECT_ROOT}/frontend/dist"
    fi

    # Install dependencies
    print_msg "$BLUE" "Installing Python dependencies..."
    "$PIP_BIN" install -e ".[webview,build]"

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

    # Install npm dependencies
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

    local ico_path="${PROJECT_ROOT}/frontend/public/AppIcon.ico"

    if [ ! -f "$ico_path" ]; then
        print_msg "$RED" "Error: Windows icon not found at $ico_path"
        exit 1
    fi

    print_msg "$GREEN" "Icon found at: $ico_path"
}

# Build app with PyInstaller
build_app() {
    print_section "Building Windows App with PyInstaller"

    print_msg "$BLUE" "Target architecture: $ARCH"

    # Clean previous build
    if [ -d "$BUILD_DIR/SearchAPIWebUI" ] || [ -d "$DIST_DIR/SearchAPIWebUI" ]; then
        print_msg "$YELLOW" "Cleaning previous build..."
        rm -rf "$BUILD_DIR/SearchAPIWebUI"
        rm -rf "$DIST_DIR/SearchAPIWebUI"
    fi

    # Run PyInstaller (use from venv)
    print_msg "$BLUE" "Running PyInstaller..."
    if [ -f "$VENV_DIR/Scripts/pyinstaller.exe" ]; then
        "$VENV_DIR/Scripts/pyinstaller.exe" --clean --noconfirm "$SPEC_FILE"
    elif [ -f "$VENV_DIR/bin/pyinstaller" ]; then
        "$VENV_DIR/bin/pyinstaller" --clean --noconfirm "$SPEC_FILE"
    else
        pyinstaller --clean --noconfirm "$SPEC_FILE"
    fi

    # Check if app directory was created
    local app_path="${DIST_DIR}/SearchAPIWebUI"
    if [ ! -d "$app_path" ]; then
        print_msg "$RED" "Error: App build failed - distribution directory not found"
        exit 1
    fi

    print_msg "$GREEN" "App built successfully at: $app_path"
}

# Main build process
main() {
    print_msg "$GREEN" "========================================="
    print_msg "$GREEN" "Search API WebUI - Windows App Builder"
    print_msg "$GREEN" "========================================="
    print_msg "$BLUE" "Architecture: $ARCH"
    echo ""

    check_dependencies
    setup_venv
    build_frontend
    verify_icon
    build_app

    print_section "Build Complete!"
    print_msg "$GREEN" "Your app is ready at:"
    print_msg "$GREEN" "  ${DIST_DIR}/SearchAPIWebUI/SearchAPIWebUI.exe"
    echo ""
    print_msg "$YELLOW" "Next steps:"
    print_msg "$YELLOW" "  1. Test the app: ${DIST_DIR}/SearchAPIWebUI/SearchAPIWebUI.exe"
    print_msg "$YELLOW" "  2. Create installer: powershell -ExecutionPolicy Bypass -File ./scripts/create_installer.ps1"
    echo ""
}

# Run main
main
