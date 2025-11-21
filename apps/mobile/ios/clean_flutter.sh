#!/bin/bash
# Clean Flutter framework extended attributes before code signing
if [ -d "${TARGET_BUILD_DIR}/Flutter.framework" ]; then
    find "${TARGET_BUILD_DIR}/Flutter.framework" -type f -exec xattr -c {} \; 2>/dev/null || true
    find "${TARGET_BUILD_DIR}/Flutter.framework" -type d -exec xattr -rc {} \; 2>/dev/null || true
    codesign --remove-signature "${TARGET_BUILD_DIR}/Flutter.framework/Flutter" 2>/dev/null || true
fi
