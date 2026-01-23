.PHONY: all help build-app build-dmg clean clean-all test verify-icon check-macos

# Get version from pyproject.toml
VERSION := $(shell grep '^version = ' pyproject.toml | sed 's/version = "\(.*\)"/\1/')

# Detect system architecture
UNAME_S := $(shell uname -s)
UNAME_M := $(shell uname -m)

# Set native architecture based on system
ifeq ($(UNAME_M),arm64)
    ARCH := arm64
else ifeq ($(UNAME_M),x86_64)
    ARCH := x86_64
else
    ARCH := $(UNAME_M)
endif

# Default target: build DMG for native architecture
all: check-macos build-app build-dmg
	@echo "========================================="
	@echo "Build Complete!"
	@echo "========================================="
	@ls -lh dist/SearchAPIWebUI-$(VERSION)-macOS-$(ARCH).dmg

# Check if running on macOS
check-macos:
	@if [ "$(UNAME_S)" != "Darwin" ]; then \
		echo "Error: macOS builds can only be run on macOS systems"; \
		echo "Current OS: $(UNAME_S)"; \
		exit 1; \
	fi

help:
	@echo "macOS App Build System"
	@echo ""
	@echo "System Info:"
	@echo "  Platform: $(UNAME_S) $(UNAME_M)"
	@echo "  Target Architecture: $(ARCH)"
	@echo "  Version: $(VERSION)"
	@echo ""
	@echo "Usage:"
	@echo "  make              Build DMG for native architecture (default)"
	@echo "  make all          Same as 'make'"
	@echo "  make build-app    Build .app bundle only"
	@echo "  make build-dmg    Create DMG from existing .app"
	@echo "  make test         Test the built application"
	@echo "  make clean        Clean build artifacts"
	@echo "  make clean-all    Clean everything including venv"
	@echo ""
	@echo "Advanced:"
	@echo "  make ARCH=arm64   Build for Apple Silicon"
	@echo "  make ARCH=x86_64  Build for Intel (requires x86_64 Python)"

verify-icon:
	@test -f frontend/public/AppIcon.icns && echo "✓ Icon found" || (echo "✗ Icon not found" && exit 1)

build-app: check-macos verify-icon
	@echo "Building macOS app for $(ARCH)..."
	@bash scripts/build_macos_app.sh $(ARCH)

build-dmg: check-macos
	@echo "Creating DMG for $(ARCH)..."
	@bash scripts/create_dmg.sh $(ARCH)

test:
	@echo "Testing application..."
	@open dist/SearchAPIWebUI.app

clean:
	@echo "Cleaning build artifacts..."
	@rm -rf build/SearchAPIWebUI dist/SearchAPIWebUI dist/SearchAPIWebUI.app
	@rm -f dist/SearchAPIWebUI-*-macOS-*.dmg dist/temp-*.dmg
	@echo "✓ Clean complete"

clean-all: clean
	@echo "Cleaning virtual environment..."
	@rm -rf venv-macos-build build/icons
	@echo "✓ Clean all complete"
