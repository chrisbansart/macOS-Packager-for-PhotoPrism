#!/bin/bash
#
#  build-launcher.sh
#  PhotoPrism Launcher Builder
#
#  Copyright (C) 2025 Chris Bansart (@chrisbansart)
#  https://github.com/chrisbansart
#
#  This program is free software: you can redistribute it and/or modify
#  it under the terms of the GNU General Public License as published by
#  the Free Software Foundation, either version 3 of the License, or
#  (at your option) any later version.
#
#  This program is distributed in the hope that it will be useful,
#  but WITHOUT ANY WARRANTY; without even the implied warranty of
#  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE. See the
#  GNU General Public License for more details.
#
#  You should have received a copy of the GNU General Public License
#  along with this program. If not, see <https://www.gnu.org/licenses/>.
#


set -euo pipefail

# =============================================================================
# build-launcher.sh - Compile uniquement le launcher Swift
# =============================================================================

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEMP_DIR="$SCRIPT_DIR/temp"
DIST_DIR="$SCRIPT_DIR/dist"
SWIFT_SRC="$SCRIPT_DIR/PhotoPrismLauncher/AppDelegate.swift"

echo "=============================================="
echo "PhotoPrism Launcher - Build"
echo "=============================================="

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Ce script est prévu pour macOS uniquement."
  exit 1
fi

if ! command -v swiftc &>/dev/null; then
  echo "Erreur: swiftc non trouvé. Installez Xcode Command Line Tools."
  exit 1
fi

if [[ ! -f "$SWIFT_SRC" ]]; then
  echo "Erreur: $SWIFT_SRC non trouvé"
  exit 1
fi

mkdir -p "$TEMP_DIR" "$DIST_DIR"

LAUNCHER_BUILD="$TEMP_DIR/launcher_build"
rm -rf "$LAUNCHER_BUILD" && mkdir -p "$LAUNCHER_BUILD"

echo ">> Compilation…"
swiftc \
  -O \
  -parse-as-library \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos11.0 \
  -framework Cocoa \
  -o "$LAUNCHER_BUILD/PhotoPrism" \
  "$SWIFT_SRC"

echo ">> Création du bundle .app…"
APP_DIR="$DIST_DIR/PhotoPrism.app"
APP_MACOS="$APP_DIR/Contents/MacOS"
APP_RESOURCES="$APP_DIR/Contents/Resources"

rm -rf "$APP_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$LAUNCHER_BUILD/PhotoPrism" "$APP_MACOS/"

cat > "$APP_DIR/Contents/Info.plist" << 'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PhotoPrism</string>
  <key>CFBundleDisplayName</key><string>PhotoPrism</string>
  <key>CFBundleIdentifier</key><string>app.photoprism.launcher</string>
  <key>CFBundleVersion</key><string>1.0</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>PhotoPrism</string>
  <key>LSMinimumSystemVersion</key><string>11.0</string>
  <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
EOF

echo -n "APPL????" > "$APP_DIR/Contents/PkgInfo"

codesign --force --deep --sign - "$APP_DIR"

echo
echo "=============================================="
echo "Build done!"
echo
echo "App: $APP_DIR"
echo
echo "Dossier temp: $TEMP_DIR"
echo "Dossier dist: $DIST_DIR"
echo
echo "NOTE: This bundle contains only the launcher."
echo "For a complete .pkg installer :"
echo "  ./build-photoprism-installer-with-launcher.sh"
echo "=============================================="
