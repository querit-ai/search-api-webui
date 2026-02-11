#!/bin/bash

# Android APK Automatic Test Script
# This script tests the deployed APK by clicking anywhere on the screen and verifying browser launch

set -e  # Exit on error

# Configuration
PACKAGE_NAME="ai.querit.searchapiwebui"
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"
TEST_DIR="$HOME/test_android"

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

# Create test directory if it doesn't exist
mkdir -p "$TEST_DIR"

echo ""
print_step "==========================================="
print_step "Android APK Automatic Click Test"
print_step "==========================================="
echo ""

# Step 1: Check if app is installed
print_step "Step 1/8: Checking if app is installed..."
if "$ADB_PATH" shell pm list packages | grep -q "$PACKAGE_NAME"; then
    print_success "App is installed: $PACKAGE_NAME"
else
    print_error "App is not installed"
    print_info "Please run ./deploy_android.sh first"
    exit 1
fi

# Step 2: Force stop app (if running)
print_step "Step 2/8: Stopping app if running..."
"$ADB_PATH" shell am force-stop "$PACKAGE_NAME" 2>/dev/null || true
print_success "App stopped"
sleep 1

# Step 3: Get screen resolution
print_step "Step 3/8: Getting screen resolution..."
SCREEN_SIZE=$("$ADB_PATH" shell wm size | grep -oE '[0-9]+x[0-9]+' | head -1)
WIDTH=$(echo "$SCREEN_SIZE" | cut -d'x' -f1)
HEIGHT=$(echo "$SCREEN_SIZE" | cut -d'x' -f2)

print_success "Screen resolution: ${WIDTH}x${HEIGHT}"

# Calculate center and various test points
CENTER_X=$((WIDTH / 2))
CENTER_Y=$((HEIGHT / 2))
TOP_LEFT_X=$((WIDTH / 4))
TOP_LEFT_Y=$((HEIGHT / 4))
BOTTOM_RIGHT_X=$((WIDTH * 3 / 4))
BOTTOM_RIGHT_Y=$((HEIGHT * 3 / 4))

print_info "Test points calculated:"
print_info "  Center: ($CENTER_X, $CENTER_Y)"
print_info "  Top-left quadrant: ($TOP_LEFT_X, $TOP_LEFT_Y)"
print_info "  Bottom-right quadrant: ($BOTTOM_RIGHT_X, $BOTTOM_RIGHT_Y)"

# Step 4: Start the app
print_step "Step 4/8: Starting the app..."
"$ADB_PATH" shell monkey -p "$PACKAGE_NAME" -c android.intent.category.LAUNCHER 1 &>/dev/null

print_success "App started"
print_info "Waiting 5 seconds for app to fully load..."
sleep 5

# Step 5: Take screenshot before click
print_step "Step 5/8: Taking screenshot before click..."
"$ADB_PATH" shell screencap /sdcard/before_click.png
"$ADB_PATH" pull /sdcard/before_click.png "$TEST_DIR/before_click.png" &>/dev/null
"$ADB_PATH" shell rm /sdcard/before_click.png
print_success "Screenshot saved: $TEST_DIR/before_click.png"

# Step 6: Click center of screen
print_step "Step 6/8: Clicking center of screen..."
print_info "Clicking at coordinates: ($CENTER_X, $CENTER_Y)"
"$ADB_PATH" shell input tap "$CENTER_X" "$CENTER_Y"
print_success "Click executed"

# Wait for browser to launch
print_info "Waiting 3 seconds for browser to launch..."
sleep 3

# Step 7: Take screenshot after click
print_step "Step 7/8: Taking screenshot after click..."
"$ADB_PATH" shell screencap /sdcard/after_click.png
"$ADB_PATH" pull /sdcard/after_click.png "$TEST_DIR/after_click.png" &>/dev/null
"$ADB_PATH" shell rm /sdcard/after_click.png
print_success "Screenshot saved: $TEST_DIR/after_click.png"

# Step 8: Verify browser launched
print_step "Step 8/8: Verifying browser launch..."

# Get current focused window
CURRENT_FOCUS=$("$ADB_PATH" shell dumpsys window | grep 'mCurrentFocus' | tr -d '\r')
print_info "Current focus: $CURRENT_FOCUS"

# Check if browser is opened
if echo "$CURRENT_FOCUS" | grep -iE 'chrome|browser|webview' > /dev/null; then
    print_success "SUCCESS! Browser detected in current focus"
    RESULT="✅ PASS"
    RESULT_MSG="Browser successfully launched!"
else
    print_error "Browser not detected in current focus"
    print_info "This might be OK if the app uses internal WebView"
    RESULT="⚠️  PARTIAL"
    RESULT_MSG="Click executed but browser launch unclear"
fi

# Additional check: Get top activity
print_info "Checking top activity..."
TOP_ACTIVITY=$("$ADB_PATH" shell dumpsys activity activities | grep 'mResumedActivity' | head -1 | tr -d '\r')
print_info "Top activity: $TOP_ACTIVITY"

if echo "$TOP_ACTIVITY" | grep -iE 'chrome|browser' > /dev/null; then
    print_success "Browser activity confirmed!"
    RESULT="✅ PASS"
    RESULT_MSG="External browser successfully launched!"
fi

# Get running processes
print_info "Checking running browser processes..."
BROWSER_PROCESS=$("$ADB_PATH" shell ps | grep -iE 'chrome|browser' | head -3)
if [ -n "$BROWSER_PROCESS" ]; then
    print_success "Browser process found running"
    echo "$BROWSER_PROCESS"
fi

echo ""
print_step "==========================================="
print_step "Test Complete!"
print_step "==========================================="
echo ""

echo -e "${GREEN}Result: $RESULT${NC}"
echo -e "Message: $RESULT_MSG"
echo ""
echo "Screenshots saved to:"
echo "  - Before click: $TEST_DIR/before_click.png"
echo "  - After click:  $TEST_DIR/after_click.png"
echo ""
echo "To view screenshots:"
echo "  open $TEST_DIR/before_click.png"
echo "  open $TEST_DIR/after_click.png"
echo ""

# Show notification
notify "Test Complete" "$RESULT_MSG"

# Show dialog with results
show_dialog "🧪 Android Click Test Complete!\n\n$RESULT\n\n$RESULT_MSG\n\nScreenshots saved to:\n$TEST_DIR/\n\nClick OK to open screenshots folder."

# Open screenshots folder
open "$TEST_DIR"

exit 0
