# Android APK Auto Deploy Script

This script automates the entire process of building, downloading, and installing the Android APK to your emulator after pushing to the `android-back` branch.

## Prerequisites

1. **GitHub CLI (`gh`)** - Install via Homebrew:
   ```bash
   brew install gh
   ```

2. **Authenticate GitHub CLI**:
   ```bash
   gh auth login
   ```

3. **Android Studio with SDK** - Ensure ADB is available at:
   ```
   ~/Library/Android/sdk/platform-tools/adb
   ```

4. **Running Android Emulator** - Start an emulator before running the script

## Usage

### After pushing to `android-back` branch:

```bash
./deploy_android.sh
```

## What the script does:

1. ✅ **Triggers GitHub workflow** - Starts the APK build on GitHub Actions
2. ✅ **Cleans test directory** - Removes old files from `~/test_android`
3. ✅ **Downloads APK** - Downloads the built APK from GitHub artifacts
4. ✅ **Extracts APK** - Unpacks the artifact ZIP to get the APK file
5. ✅ **Uninstalls old app** - Removes existing app from emulator: `ai.querit.searchapiwebui`
6. ✅ **Installs new APK** - Installs the fresh build to emulator
7. ✅ **Shows notification** - macOS dialog confirms completion

## Features

- **Colorful console output** - Easy to track progress
- **macOS notifications** - Get notified at each step
- **Error handling** - Stops on errors with clear messages
- **Auto-launch** - Optionally launches the app after installation
- **Safe cleanup** - Cleans up downloaded artifacts after installation

## Troubleshooting

### "GitHub CLI (gh) is not installed"
```bash
brew install gh
```

### "GitHub CLI is not authenticated"
```bash
gh auth login
```

### "ADB not found"
Make sure Android Studio is installed and SDK is set up properly.

### "No Android emulator is running"
Start an emulator from Android Studio before running the script:
- Tools → Device Manager → Start an emulator

### Workflow fails
The script will automatically open the workflow run in your browser if it fails.

## Configuration

You can modify these variables at the top of the script:

```bash
GITHUB_REPO="querit-ai/search-api-webui"     # Your GitHub repo
BRANCH="android-back"                         # Target branch
PACKAGE_NAME="ai.querit.searchapiwebui"      # Android package name
ADB_PATH="$HOME/Library/Android/sdk/platform-tools/adb"  # ADB location
```

## Notes

- The script waits for the workflow to complete (may take 5-10 minutes)
- APK is saved to `~/test_android/` for inspection
- Script requires macOS (uses `osascript` for notifications)
- For Linux/Windows, remove the notification functions or replace with alternatives

## Example Output

```
ℹ Step 1/7: Triggering GitHub workflow...
✓ Workflow triggered successfully
ℹ Waiting for workflow to complete...
..........
✓ Workflow completed successfully
ℹ Step 2/7: Cleaning local test directory...
✓ Cleaned /Users/username/test_android
✓ Created /Users/username/test_android
ℹ Step 3/7: Downloading APK artifact...
✓ Artifact downloaded successfully
ℹ Step 4/7: Extracting APK from artifact...
✓ APK extracted: SearchAPIWebUI-0.2.1-android-debug.apk
ℹ Step 5/7: Uninstalling existing APK from emulator...
✓ App uninstalled successfully
ℹ Step 6/7: Installing new APK to emulator...
✓ APK installed successfully
ℹ Step 7/7: Deployment completed!
=========================================
✓ Android APK Deploy Completed Successfully
=========================================
```

## License

MIT
