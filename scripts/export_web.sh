#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$PROJECT_DIR/build/web"

echo "=== Conquest: Web Export ==="

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
echo "Output:  $BUILD_DIR/conquest.html"

# Import resources first
"$GODOT" --headless --path "$PROJECT_DIR" --import 2>/dev/null || true

# Export Web build using the "Web" preset
"$GODOT" --headless --path "$PROJECT_DIR" --export-release "Web" "$BUILD_DIR/conquest.html"

if [ -f "$BUILD_DIR/conquest.html" ]; then
    SIZE=$(du -sh "$BUILD_DIR" | cut -f1)
    echo "Build successful: $BUILD_DIR/ ($SIZE total)"
    echo "Serve with: cd $BUILD_DIR && python3 -m http.server 8080"
else
    echo "Error: Web build was not created."
    exit 1
fi
