#!/bin/bash
set -e

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}Building Android APK (Release)${NC}"

# Auto-detect ANDROID_HOME
if [ -z "$ANDROID_HOME" ]; then
    # Try common Android SDK locations
    POSSIBLE_PATHS=(
        "$HOME/Library/Android/sdk"           # macOS default
        "$HOME/Android/Sdk"                    # Linux default
        "$HOME/android-sdk"                    # Alternative Linux location
        "/usr/local/android-sdk"               # System-wide installation
        "/opt/android-sdk"                     # Alternative system location
        "/opt/hostedtoolcache/Android"         # GitHub Actions (may vary)
    )

    for path in "${POSSIBLE_PATHS[@]}"; do
        if [ -d "$path" ]; then
            export ANDROID_HOME="$path"
            echo -e "${YELLOW}Auto-detected ANDROID_HOME: $ANDROID_HOME${NC}"
            break
        fi
    done

    if [ -z "$ANDROID_HOME" ]; then
        echo -e "${RED}Error: Android SDK not found${NC}"
        echo -e "${YELLOW}Searched in:${NC}"
        for path in "${POSSIBLE_PATHS[@]}"; do
            echo "  - $path"
        done
        echo ""
        echo -e "${YELLOW}Please install Android SDK or set ANDROID_HOME environment variable${NC}"
        echo "Installation options:"
        echo "  1. Install Android Studio (includes SDK)"
        echo "  2. Install command-line tools: https://developer.android.com/studio#command-tools"
        echo "  3. Or set ANDROID_HOME manually: export ANDROID_HOME=/path/to/sdk"
        exit 1
    fi
else
    echo -e "${YELLOW}Using existing ANDROID_HOME: $ANDROID_HOME${NC}"
fi

# Add Android SDK tools to PATH
export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"

# Auto-detect Java (JDK 17 or later required for Android Gradle plugin)
if [ -z "$JAVA_HOME" ]; then
    # Try common Java installation locations
    JAVA_PATHS=(
        "/usr/local/opt/openjdk@21/libexec/openjdk.jdk/Contents/Home"  # Homebrew macOS JDK 21
        "/usr/local/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"  # Homebrew macOS JDK 17
        "/usr/lib/jvm/java-21-openjdk"                                  # Linux JDK 21
        "/usr/lib/jvm/java-17-openjdk"                                  # Linux JDK 17
        "/usr/lib/jvm/java-21-openjdk-amd64"                           # Debian/Ubuntu JDK 21
        "/usr/lib/jvm/java-17-openjdk-amd64"                           # Debian/Ubuntu JDK 17
    )

    for java_path in "${JAVA_PATHS[@]}"; do
        if [ -d "$java_path" ]; then
            export JAVA_HOME="$java_path"
            JAVA_VERSION=$("$JAVA_HOME/bin/java" -version 2>&1 | head -n 1 | cut -d'"' -f2 | cut -d'.' -f1)
            echo -e "${YELLOW}Auto-detected Java $JAVA_VERSION: $JAVA_HOME${NC}"
            break
        fi
    done

    if [ -z "$JAVA_HOME" ]; then
        echo -e "${RED}Error: Java 17+ not found${NC}"
        echo -e "${YELLOW}Searched in:${NC}"
        for java_path in "${JAVA_PATHS[@]}"; do
            echo "  - $java_path"
        done
        echo ""
        echo -e "${YELLOW}Please install JDK 17 or later:${NC}"
        echo "  macOS:   brew install openjdk@21"
        echo "  Ubuntu:  sudo apt install openjdk-21-jdk"
        echo "  Or set JAVA_HOME manually: export JAVA_HOME=/path/to/jdk"
        exit 1
    fi
else
    echo -e "${YELLOW}Using existing JAVA_HOME: $JAVA_HOME${NC}"
fi

# Get version from pyproject.toml
VERSION=$(grep -E '^version = ' pyproject.toml | cut -d '"' -f 2)
echo -e "${YELLOW}Version: $VERSION${NC}"

# Build frontend
echo -e "${YELLOW}Building frontend...${NC}"
cd frontend
npm ci
npm run build
npx cap sync android

# Build Release APK (signed with debug keystore)
echo -e "${YELLOW}Building release APK (signed with debug keystore)...${NC}"
cd android
./gradlew assembleRelease

# Copy to dist
cd ../..
mkdir -p dist
cp frontend/android/app/build/outputs/apk/release/app-release.apk \
   "dist/SearchAPIWebUI-${VERSION}.apk"

echo ""
echo -e "${GREEN}=========================================${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}=========================================${NC}"
ls -lh "dist/SearchAPIWebUI-${VERSION}.apk"
echo ""
echo "Release APK: dist/SearchAPIWebUI-${VERSION}.apk"
echo ""
echo "Note: This APK is signed with Android debug keystore."
echo "It can be installed directly on any device for testing."
