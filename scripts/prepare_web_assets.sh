#!/bin/bash
# ============================================
# Prepare Web Assets for Mobile PWA Hosting
# ============================================
# This script copies the Flutter web build to assets/web
# so that the Android APK can serve PWA to clients

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

cd "$PROJECT_DIR"

echo "[1/3] Building Flutter Web..."
flutter build web --release

echo "[2/3] Copying web build to assets/web..."

# Clear existing assets/web (except .gitkeep)
find assets/web -mindepth 1 ! -name '.gitkeep' -delete 2>/dev/null || true

# Copy build/web to assets/web
cp -r build/web/* assets/web/

echo "[3/3] Web assets prepared successfully!"
echo ""
echo "Now you can build the APK:"
echo "  flutter build apk --release"