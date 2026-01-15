#!/bin/bash

# 1. Exit immediately on error
set -e

echo "Starting build process..."

# 2. Clean previous build artifacts
echo "Cleaning old files..."
rm -rf frontend/dist
rm -rf dist

# 3. Build frontend
echo "Building React frontend..."
cd frontend
npm install
npm run build
cd ..

if [ ! -f "frontend/dist/index.html" ]; then
    echo "Error: Frontend build failed, index.html not found"
    exit 1
fi

# 4. Build Python Artifacts (Modified)
echo "Building Python Artifacts..."

python3 -m build --wheel
python3 -m build --sdist

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
