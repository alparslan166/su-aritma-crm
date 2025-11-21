#!/bin/bash
# Clean Flutter framework extended attributes before code signing
set -e

# Clean Flutter framework in build directory
FLUTTER_FRAMEWORK="${TARGET_BUILD_DIR}/Flutter.framework"
if [ -d "$FLUTTER_FRAMEWORK" ]; then
    echo "Cleaning extended attributes from Flutter.framework..."
    find "$FLUTTER_FRAMEWORK" -type f -exec xattr -c {} \; 2>/dev/null || true
    find "$FLUTTER_FRAMEWORK" -type d -exec xattr -rc {} \; 2>/dev/null || true
    if [ -f "$FLUTTER_FRAMEWORK/Flutter" ]; then
        codesign --remove-signature "$FLUTTER_FRAMEWORK/Flutter" 2>/dev/null || true
    fi
    echo "Cleaned Flutter.framework"
fi

# Also clean in project build directory
PROJECT_BUILD_DIR="${PROJECT_DIR}/build/ios/Debug-iphonesimulator/Flutter.framework"
if [ -d "$PROJECT_BUILD_DIR" ]; then
    echo "Cleaning extended attributes from project Flutter.framework..."
    find "$PROJECT_BUILD_DIR" -type f -exec xattr -c {} \; 2>/dev/null || true
    find "$PROJECT_BUILD_DIR" -type d -exec xattr -rc {} \; 2>/dev/null || true
    if [ -f "$PROJECT_BUILD_DIR/Flutter" ]; then
        codesign --remove-signature "$PROJECT_BUILD_DIR/Flutter" 2>/dev/null || true
    fi
    echo "Cleaned project Flutter.framework"
fi
