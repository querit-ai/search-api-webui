# Building macOS Application

This guide explains how to build a native macOS application bundle and DMG installer for Search API WebUI.

## Overview

The build system creates a standalone macOS `.app` bundle using PyInstaller, then packages it into a distributable `.dmg` file. The app runs in webview mode (native window) instead of opening a browser.

## Prerequisites

- macOS 10.13 or later
- Python 3.14+ (or compatible version)
- Node.js and npm (for frontend build)
- Command Line Tools (for `iconutil`, `hdiutil`)

## Build Scripts

The build system is integrated into a simple Makefile that automatically detects your architecture.

### Primary Command

#### `make` or `make all` (Recommended)

Builds a DMG file for your native architecture with a single command.

**Requirements:** Must be run on macOS (Darwin)

**Usage:**
```bash
make          # Build for native architecture
# or
make all      # Same as 'make'
```

**What it does:**
1. Checks that you're running on macOS
2. Detects your system architecture (arm64 or x86_64)
3. Builds the .app bundle for your architecture
4. Creates a DMG installer

**Output:**
- On Apple Silicon: `dist/SearchAPIWebUI-<version>-macOS-arm64.dmg`
- On Intel Mac: `dist/SearchAPIWebUI-<version>-macOS-x86_64.dmg`

**Example:**
```bash
make
# Output: SearchAPIWebUI-0.1.7-macOS-arm64.dmg (on Apple Silicon)
```

### Other Useful Commands

```bash
make help         # Show all available commands
make clean        # Clean build artifacts
make clean-all    # Clean everything including venv
make test         # Test the built .app
```

### Advanced: Cross-Architecture Build

To build for a different architecture, use the `ARCH` parameter:

```bash
make ARCH=x86_64  # Build for Intel (requires x86_64 Python on arm64)
make ARCH=arm64   # Build for Apple Silicon
```

**Note:** Cross-compiling on Apple Silicon requires x86_64 Python (see Architecture Support section).

## Supporting Build Scripts

#### 1. Architecture-Specific Build: `scripts/build_macos_app.sh`

Builds the complete macOS application bundle.

**Usage via Makefile (Recommended):**
```bash
# Build for Apple Silicon (arm64) - default
make build-app

# Build for Intel (x86_64)
make build-app ARCH=x86_64
```

**Direct script usage:**
```bash
# Build for Apple Silicon (arm64) - default
./scripts/build_macos_app.sh

# Build for Intel (x86_64)
./scripts/build_macos_app.sh x86_64
```

**What it does:**
1. Checks dependencies (python3, npm, iconutil)
2. Creates or reuses virtual environment (`venv-macos-build`)
3. Installs Python dependencies including pywebview and pyinstaller
4. Builds frontend assets (`npm run build`)
5. Verifies app icon exists (`frontend/public/AppIcon.icns`)
6. Runs PyInstaller using the spec file
7. Creates a wrapper script to pass `-w` flag for webview mode

**Output:** `dist/SearchAPIWebUI.app`

#### 2. DMG Creator: `scripts/create_dmg.sh`

Packages the app into a distributable DMG file with proper naming.

**Usage via Makefile (Recommended):**
```bash
# Create DMG for the last built architecture (default: arm64)
make build-dmg

# Create DMG for specific architecture
make build-dmg ARCH=arm64
make build-dmg ARCH=x86_64
```

**Direct script usage:**
```bash
# Create DMG for the last built architecture (default: arm64)
./scripts/create_dmg.sh

# Create DMG for specific architecture
./scripts/create_dmg.sh arm64
./scripts/create_dmg.sh x86_64
```

**What it does:**
1. Creates a temporary disk image
2. Copies the app to the image
3. Creates an Applications folder symlink
4. Sets custom icon and layout
5. Compresses the final DMG

**Output:** `dist/SearchAPIWebUI-<version>-macOS-<arch>.dmg`

## PyInstaller Spec File

The build configuration is defined in [SearchAPIWebUI.spec](SearchAPIWebUI.spec):

- **Entry point:** `search_api_webui/app.py`
- **Mode:** `onedir` (all files in a directory)
- **Architecture:** Configurable (arm64 or x86_64)
- **Icon:** `frontend/public/AppIcon.icns`
- **Data files:**
  - `providers.yaml` → bundled in `_MEIPASS`
  - `frontend/dist` → bundled as `static/`

## Quick Start

### Simplest Way (Recommended)

Build for your current Mac with one command:

```bash
make
```

That's it! The DMG will be created at `dist/SearchAPIWebUI-<version>-macOS-<arch>.dmg`

### Step by Step (if needed)

If you want more control:

```bash
# 1. Build just the .app
make build-app

# 2. Test it
make test

# 3. Create DMG
make build-dmg
```

### Manual Build with Scripts (Advanced)

Build for a specific architecture using scripts directly:

```bash
# 1. Build the app
./scripts/build_macos_app.sh arm64  # or x86_64

# 2. Test it
open dist/SearchAPIWebUI.app

# 3. Create DMG
./scripts/create_dmg.sh arm64  # or x86_64
```

## Architecture Support

The build system automatically detects your Mac's architecture and builds appropriate versions:

### Apple Silicon Macs (M1/M2/M3/M4)
- **Native:** arm64
- **Can build:** arm64 only (recommended)
- **Note:** Cross-compiling to x86_64 requires x86_64 Python installation via Rosetta

### Intel Macs
- **Native:** x86_64
- **Can build:** Both x86_64 and arm64

### Cross-Compilation on Apple Silicon

To build x86_64 versions on Apple Silicon, you need x86_64 Python:

```bash
# Install x86_64 Homebrew under Rosetta
arch -x86_64 /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Install x86_64 Python
arch -x86_64 /usr/local/bin/brew install python@3.14

# Use x86_64 Python for building
arch -x86_64 /usr/local/bin/python3 -m venv venv-x86
source venv-x86/bin/activate
# Then run build scripts
```

**Recommendation:** For most users, building only the native architecture is sufficient. Users on different architectures can build their own versions.

## Virtual Environment

The build script uses a virtual environment with prefix `venv-`:
- Location: `venv-macos-build/`
- Reusable across builds to save time
- Includes all dependencies: Flask, pywebview, pyinstaller, etc.

## Troubleshooting

### Icon not showing
Make sure `frontend/public/AppIcon.icns` exists:
```bash
make verify-icon
```

### Frontend not found
Build the frontend first:
```bash
cd frontend
npm install
npm run build
cd ..
```

### Resource not found in app
The app uses `sys._MEIPASS` to locate bundled resources. Check [app.py](search_api_webui/app.py) for path resolution logic.

### App won't open
Check for security warnings:
```bash
# Remove quarantine attribute if needed
xattr -d com.apple.quarantine dist/SearchAPIWebUI.app
```

## Distribution

The DMG file follows this naming convention:

**Format:** `SearchAPIWebUI-<version>-macOS-<arch>.dmg`

**Examples:**
- `SearchAPIWebUI-0.1.7-macOS-arm64.dmg` → For Apple Silicon (M1/M2/M3/M4)
- `SearchAPIWebUI-0.1.7-macOS-x86_64.dmg` → For Intel Macs

Users install by:
1. Double-clicking the DMG to mount it
2. Dragging `SearchAPIWebUI.app` to the Applications folder
3. Launching from Applications or Spotlight

## Code Signing (Optional)

For distribution outside your organization, you'll need to sign the app:

```bash
# Sign the app
codesign --force --deep --sign "Developer ID Application: Your Name" dist/SearchAPIWebUI.app

# Notarize (requires Apple Developer account)
xcrun notarytool submit dist/SearchAPIWebUI-<version>-macOS-<arch>.dmg --wait
```

## Project Structure

```
search-api-webui/
├── Makefile                     # Build system with macOS check
├── SearchAPIWebUI.spec          # PyInstaller configuration
├── scripts/
│   ├── build_macos_app.sh      # Architecture-specific build
│   └── create_dmg.sh           # DMG packaging
├── frontend/
│   └── public/
│       └── AppIcon.icns        # macOS app icon
└── dist/
    ├── SearchAPIWebUI.app                              # Built application
    ├── SearchAPIWebUI-<version>-macOS-arm64.dmg       # arm64 DMG
    └── SearchAPIWebUI-<version>-macOS-x86_64.dmg      # x86_64 DMG
```

## Notes

- **Platform Check:** `make build-mac` and other build targets automatically check that you're running on macOS (Darwin). Non-macOS systems will receive an error message.
- The app launches in **webview mode** (`-w` flag) by default
- All Python dependencies are bundled (onedir mode)
- Frontend assets are included in the bundle
- Configuration is stored in `~/.search-api-webui/config.json`
- The build system is idempotent - safe to run multiple times
- Version number is automatically extracted from `pyproject.toml`
