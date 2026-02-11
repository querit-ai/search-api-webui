#!/bin/bash

# Android APK Auto Deploy Script
# This script triggers GitHub workflow, downloads the built APK, and installs it to Android emulator
# Usage: ./deploy_android.sh

set -e  # Exit on error

# Configuration
GITHUB_REPO="querit-ai/search-api-webui"
BRANCH="android-back"
WORKFLOW_FILE="build-release.yml"
TEST_DIR="$HOME/test_android"
PACKAGE_NAME="ai.querit.searchapiwebui"
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print colored messages
print_success() {
    echo -e "${GREEN}✓ $1${NC}"
}

print_error() {
    echo -e "${RED}✗ $1${NC}"
}

print_info() {
    echo -e "${YELLOW}ℹ $1${NC}"
}

# Function to show macOS notification
notify() {
    osascript -e "display notification \"$2\" with title \"Android Deploy\" subtitle \"$1\""
}

# Function to show macOS dialog
show_dialog() {
    osascript -e "display dialog \"$1\" with title \"Android Deploy\" buttons {\"OK\"} default button \"OK\""
}

# Check if gh CLI is installed
if ! command -v gh &> /dev/null; then
    print_error "GitHub CLI (gh) is not installed. Please install it first:"
    print_info "brew install gh"
    notify "Error" "GitHub CLI not installed"
    exit 1
fi

# Check if gh is authenticated
if ! gh auth status &> /dev/null; then
    print_error "GitHub CLI is not authenticated. Please run:"
    print_info "gh auth login"
    notify "Error" "GitHub CLI not authenticated"
    exit 1
fi

# Check if ADB exists
if [ ! -f "$ADB_PATH" ]; then
    print_error "ADB not found at: $ADB_PATH"
    print_info "Please make sure Android SDK is installed"
    notify "Error" "ADB not found"
    exit 1
fi

# Step 1: Trigger GitHub workflow
print_info "Step 1/7: Triggering GitHub workflow..."
if gh workflow run "$WORKFLOW_FILE" --repo "$GITHUB_REPO" --ref "$BRANCH"; then
    print_success "Workflow triggered successfully"
    notify "Step 1/7" "Workflow triggered"
else
    print_error "Failed to trigger workflow"
    notify "Error" "Failed to trigger workflow"
    exit 1
fi

# Wait for workflow to start
print_info "Waiting for workflow to start (10 seconds)..."
sleep 10

# Get the latest workflow run
print_info "Getting latest workflow run..."
RUN_ID=$(gh run list --repo "$GITHUB_REPO" --workflow "$WORKFLOW_FILE" --branch "$BRANCH" --limit 1 --json databaseId --jq '.[0].databaseId')

if [ -z "$RUN_ID" ]; then
    print_error "Failed to get workflow run ID"
    notify "Error" "Failed to get workflow run"
    exit 1
fi

print_success "Workflow run ID: $RUN_ID"

# Wait for workflow to complete
print_info "Waiting for workflow to complete (this may take several minutes)..."
notify "Building" "APK build in progress..."

# Poll workflow status
while true; do
    STATUS=$(gh run view "$RUN_ID" --repo "$GITHUB_REPO" --json status --jq '.status')
    CONCLUSION=$(gh run view "$RUN_ID" --repo "$GITHUB_REPO" --json conclusion --jq '.conclusion')

    if [ "$STATUS" = "completed" ]; then
        if [ "$CONCLUSION" = "success" ]; then
            print_success "Workflow completed successfully"
            break
        else
            print_error "Workflow failed with conclusion: $CONCLUSION"
            gh run view "$RUN_ID" --repo "$GITHUB_REPO" --web
            notify "Error" "Workflow failed: $CONCLUSION"
            exit 1
        fi
    fi

    # Show progress
    echo -n "."
    sleep 10
done
echo ""

# Step 2: Clean local test directory
print_info "Step 2/7: Cleaning local test directory..."
if [ -d "$TEST_DIR" ]; then
    rm -rf "$TEST_DIR"
    print_success "Cleaned $TEST_DIR"
else
    print_info "Directory $TEST_DIR does not exist, skipping"
fi

# Create fresh directory
mkdir -p "$TEST_DIR"
print_success "Created $TEST_DIR"
notify "Step 2/7" "Test directory cleaned"

# Step 3: Download APK artifact
print_info "Step 3/7: Downloading APK artifact..."
cd "$TEST_DIR"

# Download all artifacts from the run (gh CLI will list them)
print_info "Downloading artifacts from run $RUN_ID..."
if gh run download "$RUN_ID" --repo "$GITHUB_REPO" --dir "$TEST_DIR"; then
    print_success "Artifacts downloaded successfully"
    notify "Step 3/7" "APK downloaded"
else
    print_error "Failed to download artifacts"
    notify "Error" "Failed to download artifacts"
    exit 1
fi

# Step 4: Extract APK from ZIP
print_info "Step 4/7: Extracting APK from artifact..."

# Find the downloaded directory (artifact is in a subdirectory)
ARTIFACT_DIR=$(find "$TEST_DIR" -type d -name "SearchAPIWebUI-*-android" | head -1)

if [ -z "$ARTIFACT_DIR" ]; then
    print_error "Downloaded artifact directory not found"
    notify "Error" "Artifact directory not found"
    exit 1
fi

# Find the APK file
APK_FILE=$(find "$ARTIFACT_DIR" -name "*.apk" -type f | head -1)

if [ -z "$APK_FILE" ]; then
    print_error "APK file not found in artifact"
    notify "Error" "APK file not found"
    exit 1
fi

# Move APK to test directory root
APK_BASENAME=$(basename "$APK_FILE")
mv "$APK_FILE" "$TEST_DIR/$APK_BASENAME"
APK_FILE="$TEST_DIR/$APK_BASENAME"

# Clean up artifact directory
rm -rf "$ARTIFACT_DIR"

print_success "APK extracted: $APK_BASENAME"
print_info "APK location: $APK_FILE"
notify "Step 4/7" "APK extracted"

# Check if emulator is running
print_info "Checking for running Android emulator..."
DEVICES=$("$ADB_PATH" devices | grep -v "List" | grep "device$" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    print_error "No Android emulator is running"
    print_info "Please start an emulator first"
    notify "Error" "No emulator running"
    exit 1
fi

print_success "Found running emulator"

# Step 5: Uninstall existing APK
print_info "Step 5/7: Uninstalling existing APK from emulator..."

# Check if app is installed
if "$ADB_PATH" shell pm list packages | grep -q "$PACKAGE_NAME"; then
    print_info "App is installed, uninstalling..."
    if "$ADB_PATH" uninstall "$PACKAGE_NAME" &> /dev/null; then
        print_success "App uninstalled successfully"
    else
        print_error "Failed to uninstall app (this is OK if app wasn't installed)"
    fi
else
    print_info "App is not installed, skipping uninstall"
fi
notify "Step 5/7" "Old app removed"

# Step 6: Install new APK
print_info "Step 6/7: Installing new APK to emulator..."

if "$ADB_PATH" install "$APK_FILE"; then
    print_success "APK installed successfully"
    notify "Step 6/7" "APK installed"
else
    print_error "Failed to install APK"
    notify "Error" "Failed to install APK"
    exit 1
fi

# Step 7: Show completion notification
print_info "Step 7/7: Deployment completed!"
print_success "========================================="
print_success "Android APK Deploy Completed Successfully"
print_success "========================================="
print_success "Package: $PACKAGE_NAME"
print_success "APK Location: $APK_FILE"
print_success "========================================="

# Show dialog notification
show_dialog "🎉 Android APK Deploy Completed!\n\nPackage: $PACKAGE_NAME\nAPK: $APK_BASENAME\n\nThe app has been successfully installed to your emulator."

# Optional: Launch the app
print_info "Would you like to launch the app now? (The app will auto-launch after 5 seconds)"
print_info "Press Ctrl+C to skip..."

sleep 5

print_info "Launching app..."
if "$ADB_PATH" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 &> /dev/null; then
    print_success "App launched successfully"
else
    print_info "Could not auto-launch app, please launch manually"
fi

exit 0
