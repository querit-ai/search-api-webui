#!/bin/bash

# Quick test script to verify all dependencies for deploy_android.sh

echo "🔍 Checking dependencies for deploy_android.sh..."
echo ""

# Check GitHub CLI
echo "1. Checking GitHub CLI..."
if command -v gh &> /dev/null; then
    echo "   ✅ GitHub CLI installed: $(gh --version | head -1)"
else
    echo "   ❌ GitHub CLI NOT installed"
    echo "      Install: brew install gh"
    exit 1
fi

# Check GitHub CLI authentication
echo "2. Checking GitHub CLI authentication..."
if gh auth status &> /dev/null; then
    echo "   ✅ GitHub CLI authenticated"
    gh auth status 2>&1 | head -5
else
    echo "   ❌ GitHub CLI NOT authenticated"
    echo "      Run: gh auth login"
    exit 1
fi

# Check ADB
echo ""
echo "3. Checking ADB..."
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"
if [ -f "$ADB_PATH" ]; then
    echo "   ✅ ADB found: $ADB_PATH"
    ADB_VERSION=$("$ADB_PATH" version | head -1)
    echo "      Version: $ADB_VERSION"
else
    echo "   ❌ ADB NOT found at: $ADB_PATH"
    echo "      Please install Android Studio and SDK"
    exit 1
fi

# Check for running emulator
echo ""
echo "4. Checking for running Android emulator..."
DEVICES=$("$ADB_PATH" devices | grep -v "List" | grep "device$" | wc -l)
if [ "$DEVICES" -gt 0 ]; then
    echo "   ✅ Found $DEVICES running emulator(s)"
    "$ADB_PATH" devices
else
    echo "   ⚠️  No emulator currently running"
    echo "      This is OK - just start one before running deploy_android.sh"
fi

# Check test directory
echo ""
echo "5. Checking test directory..."
TEST_DIR="$HOME/test_android"
if [ -d "$TEST_DIR" ]; then
    echo "   ✅ Test directory exists: $TEST_DIR"
    echo "      Contents: $(ls -1 "$TEST_DIR" 2>/dev/null | wc -l) files"
else
    echo "   ℹ️  Test directory doesn't exist yet (will be created automatically)"
fi

# Check repository access
echo ""
echo "6. Checking GitHub repository access..."
GITHUB_REPO="querit-ai/search-api-webui"
if gh repo view "$GITHUB_REPO" --json name &> /dev/null; then
    echo "   ✅ Can access repository: $GITHUB_REPO"
else
    echo "   ❌ Cannot access repository: $GITHUB_REPO"
    echo "      Make sure you have permission to access this repo"
    exit 1
fi

# Check workflow file
echo ""
echo "7. Checking workflow file..."
WORKFLOW_FILE="build-release.yml"
if gh workflow view "$WORKFLOW_FILE" --repo "$GITHUB_REPO" &> /dev/null; then
    echo "   ✅ Workflow file found: $WORKFLOW_FILE"
else
    echo "   ❌ Workflow file NOT found: $WORKFLOW_FILE"
    exit 1
fi

echo ""
echo "========================================="
echo "✅ All dependencies are ready!"
echo "========================================="
echo ""
echo "You can now run: ./deploy_android.sh"
echo ""
echo "Note: Make sure an Android emulator is running before executing the deploy script."
echo ""
