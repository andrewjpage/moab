#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/android"

echo "=== Conquest: Android APK Export ==="

# Ensure build directory exists
mkdir -p "$BUILD_DIR"

# Find Godot binary
GODOT="${GODOT_BIN:-godot}"
if ! command -v "$GODOT" &> /dev/null; then
    echo "Error: Godot binary not found."
    echo "Set GODOT_BIN environment variable or add godot to PATH."
    exit 1
fi

echo "Using Godot: $GODOT"
echo "Project: $PROJECT_DIR"
echo "Output:  $BUILD_DIR/conquest.apk"

# Import resources first
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>/dev/null || true

# Export APK using the "Android APK" preset
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Android APK" "$BUILD_DIR/conquest.apk"

if [ -f "$BUILD_DIR/conquest.apk" ]; then
    SIZE=$(du -h "$BUILD_DIR/conquest.apk" | cut -f1)
    echo "Build successful: $BUILD_DIR/conquest.apk ($SIZE)"
else
    echo "Error: APK was not created."
    exit 1
fi
