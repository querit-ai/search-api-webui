.PHONY: all help dev backend frontend dmg build-app build-dmg clean clean-all test verify-icon check-macos

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

# Default target: build Python wheel
all:
	@echo "Building Python wheel package..."
	@$(MAKE) build-wheel

help:
	@echo "Search API WebUI - Build System"
	@echo ""
	@echo "System Info:"
	@echo "  Platform: $(UNAME_S) $(UNAME_M)"
	@echo "  Architecture: $(ARCH)"
	@echo "  Version: $(VERSION)"
	@echo ""
	@echo "Common Commands:"
	@echo "  make              Build Python wheel package (default)"
	@echo "  make dev          Start development servers (frontend + backend)"
	@echo "  make dmg          Build DMG for current architecture ($(ARCH))"
	@echo ""
	@echo "Development:"
	@echo "  make backend      Start backend server only"
	@echo "  make frontend     Start frontend dev server only"
	@echo ""
	@echo "macOS App Build:"
	@echo "  make build-app    Build .app bundle only"
	@echo "  make build-dmg    Create DMG from existing .app"
	@echo "  make test         Test the built application"
	@echo ""
	@echo "Utilities:"
	@echo "  make clean        Clean build artifacts"
	@echo "  make clean-all    Clean everything including venv"
	@echo ""
	@echo "Advanced:"
	@echo "  make ARCH=arm64   Build for Apple Silicon"
	@echo "  make ARCH=x86_64  Build for Intel (requires x86_64 Python)"

check-macos:
	@if [ "$(UNAME_S)" != "Darwin" ]; then \
		echo "Error: macOS builds can only be run on macOS systems"; \
		echo "Current OS: $(UNAME_S)"; \
		exit 1; \
	fi

verify-icon:
	@test -f frontend/public/AppIcon.icns && echo "✓ Icon found" || (echo "✗ Icon not found" && exit 1)

# Python wheel build
build-wheel:
	@echo "Building Python wheel package..."
	@echo "Step 1/3: Installing dependencies..."
	@cd frontend && npm ci
	@echo "Step 2/3: Building frontend..."
	@cd frontend && npm run build
	@echo "Step 3/3: Building wheel..."
	@python -m pip install --upgrade pip
	@pip install hatchling build
	@python -m build --wheel
	@echo ""
	@echo "========================================="
	@echo "Build Complete!"
	@echo "========================================="
	@ls -lh dist/*.whl

# macOS DMG build (for current architecture)
dmg: check-macos
	@echo "Building DMG for $(ARCH)..."
	@$(MAKE) build-app
	@$(MAKE) build-dmg
	@echo ""
	@echo "========================================="
	@echo "DMG Build Complete!"
	@echo "========================================="
	@ls -lh dist/SearchAPIWebUI-$(VERSION)-macOS-$(ARCH).dmg

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
	@rm -rf dist/*.whl build
	@echo "✓ Clean complete"

clean-all: clean
	@echo "Cleaning virtual environment..."
	@rm -rf venv-macos-build build/icons
	@echo "✓ Clean all complete"

# Development targets
dev:
	@echo "========================================="
	@echo "Starting Development Servers"
	@echo "========================================="
	@echo "Backend: http://localhost:8889"
	@echo "Frontend: http://localhost:5173"
	@echo ""
	@echo "Press Ctrl+C to stop both servers"
	@echo "========================================="
	@make -j3 backend frontend open-browser

backend:
	@echo "Starting Flask backend with hot reload..."
	FLASK_DEBUG=1 python -m flask --app search_api_webui.app run --port 8889 --debug

frontend:
	@echo "Starting Vite frontend dev server..."
	cd frontend && npm run dev

open-browser:
	@echo "Waiting for servers to start..."
	@sleep 3
	@echo "Opening browser..."
	@open http://localhost:5173 2>/dev/null || true
