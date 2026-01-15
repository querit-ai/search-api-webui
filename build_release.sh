#!/bin/bash

# 1. Exit immediately on error
set -e

echo "Starting build process..."

# 2. Clean previous build artifacts
echo "Cleaning old files..."
rm -rf dist
rm -rf backend/static
mkdir -p backend/static

# 3. Build frontend
echo "Building React frontend..."
cd frontend
npm install
npm run build
cd ..

# The frontend vite.config.js should be configured to output to ../backend/static
# If not, we would need to move manually, but your config has outDir: '../backend/static', so no action needed.

# Check if frontend build output exists
if [ ! -f "backend/static/index.html" ]; then
    echo "Error: Frontend build failed, index.html not found"
    exit 1
fi

# 4. Build Python Wheel
echo "Building Python Wheel..."
python3 -m build

echo "Build complete!"
echo "Artifacts are in the dist/ directory"

# 5. (Optional) Prompt for upload
read -p "Upload to PyPI now? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]
then
    echo "Uploading..."
    twine upload dist/*
fi
