#!/bin/bash

# Android APK Automatic Test Script
# This script tests the deployed APK by clicking the screen and verifying browser launch

set -e  # Exit on error

# Configuration
PACKAGE_NAME="ai.querit.searchapiwebui"
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

print_step() {
    echo -e "${BLUE}▶ $1${NC}"
}

# Function to show macOS notification
notify() {
    osascript -e "display notification \"$2\" with title \"Android Test\" subtitle \"$1\""
}

# Function to show macOS dialog
show_dialog() {
    osascript -e "display dialog \"$1\" with title \"Android Test\" buttons {\"OK\"} default button \"OK\""
}

# Check if ADB exists
if [ ! -f "$ADB_PATH" ]; then
    print_error "ADB not found at: $ADB_PATH"
    exit 1
fi

# Check if emulator is running
print_info "Checking for running Android emulator..."
DEVICES=$("$ADB_PATH" devices | grep -v "List" | grep "device$" | wc -l)

if [ "$DEVICES" -eq 0 ]; then
    print_error "No Android emulator is running"
    print_info "Please start an emulator first"
    exit 1
fi

print_success "Found running emulator"

echo ""
print_step "==========================================="
print_step "Android APK Browser Launch Test"
print_step "==========================================="
echo ""

# Step 1: Check if app is installed
print_step "Step 1/5: Checking if app is installed..."
if "$ADB_PATH" shell pm list packages | grep -q "$PACKAGE_NAME"; then
    print_success "App is installed: $PACKAGE_NAME"
else
    print_error "App is not installed"
    print_info "Please run ./deploy_android.sh first"
    exit 1
fi

# Step 2: Force stop app (if running)
print_step "Step 2/5: Stopping app if running..."
"$ADB_PATH" shell am force-stop "$PACKAGE_NAME" 2>/dev/null || true
print_success "App stopped"
sleep 1

# Step 3: Start the app
print_step "Step 3/5: Starting the app..."
"$ADB_PATH" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 &>/dev/null

print_success "App started"
print_info "Waiting 5 seconds for app to fully load..."
sleep 5

# Step 4: Click screen (app is fullscreen clickable)
print_step "Step 4/5: Clicking the screen..."
# Get screen resolution for center point
SCREEN_SIZE=$("$ADB_PATH" shell wm size | grep -oE '[0-9]+x[0-9]+' | head -1)
WIDTH=$(echo "$SCREEN_SIZE" | cut -d'x' -f1)
HEIGHT=$(echo "$SCREEN_SIZE" | cut -d'x' -f2)
CENTER_X=$((WIDTH / 2))
CENTER_Y=$((HEIGHT / 2))

print_info "Clicking at screen center: ($CENTER_X, $CENTER_Y)"
"$ADB_PATH" shell input tap "$CENTER_X" "$CENTER_Y"
print_success "Click executed"

# Wait for browser to launch
print_info "Waiting 5 seconds for browser to launch..."
sleep 5

# Step 5: Verify browser launched
print_step "Step 5/5: Verifying external browser launch..."

# Get current focused window
CURRENT_FOCUS=$("$ADB_PATH" shell dumpsys window | grep 'mCurrentFocus' | tr -d '\r')
print_info "Current focus: $CURRENT_FOCUS"

# Check if browser is opened
if echo "$CURRENT_FOCUS" | grep -iE 'chrome|browser' > /dev/null; then
    print_success "SUCCESS! External browser detected in current focus"
    RESULT="✅ PASS"
    RESULT_MSG="External browser successfully launched!"
else
    print_error "External browser not detected in current focus"
    RESULT="❌ FAIL"
    RESULT_MSG="External browser was NOT launched"
fi

# Additional check: Get top activity
print_info "Checking top activity..."
TOP_ACTIVITY=$("$ADB_PATH" shell dumpsys activity activities | grep 'mResumedActivity' | head -1 | tr -d '\r')
print_info "Top activity: $TOP_ACTIVITY"

if echo "$TOP_ACTIVITY" | grep -iE 'chrome|browser' > /dev/null; then
    print_success "External browser activity confirmed!"
    RESULT="✅ PASS"
    RESULT_MSG="External browser successfully launched!"
fi

# Get running processes
print_info "Checking running browser processes..."
BROWSER_PROCESS=$("$ADB_PATH" shell ps | grep -iE 'chrome|browser' | head -3)
if [ -n "$BROWSER_PROCESS" ]; then
    print_success "Browser process found running:"
    echo "$BROWSER_PROCESS"
else
    print_error "No browser process found"
fi

echo ""
print_step "==========================================="
print_step "Test Complete!"
print_step "==========================================="
echo ""

echo -e "${GREEN}Result: $RESULT${NC}"
echo -e "Message: $RESULT_MSG"
echo ""

# Show notification
notify "Test Complete" "$RESULT_MSG"

# Show dialog with results
show_dialog "🧪 Browser Launch Test Complete!\n\n$RESULT\n\n$RESULT_MSG"

exit 0
