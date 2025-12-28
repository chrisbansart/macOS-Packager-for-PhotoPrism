#!/bin/bash
#
#  build-photoprism-installer-with-launcher.sh
#  PhotoPrism Server and Launcher macOS installer builder (.pkg and .dmg)
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

### --------------------------------------------------------------------
### PhotoPrism macOS Installer with Swift Launcher
### --------------------------------------------------------------------

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Output format options (can be overridden via environment or arguments)
BUILD_PKG="${BUILD_PKG:-1}"
BUILD_DMG="${BUILD_DMG:-1}"
BUILD_APP_ONLY="${BUILD_APP_ONLY:-0}"

# Parse command line arguments
while [[ $# -gt 0 ]]; do
  case $1 in
    --app-only)
      BUILD_PKG=0
      BUILD_DMG=0
      BUILD_APP_ONLY=1
      shift
      ;;
    --pkg-only)
      BUILD_PKG=1
      BUILD_DMG=0
      BUILD_APP_ONLY=0
      shift
      ;;
    --dmg-only)
      BUILD_PKG=0
      BUILD_DMG=1
      BUILD_APP_ONLY=0
      shift
      ;;
    --both)
      BUILD_PKG=1
      BUILD_DMG=1
      BUILD_APP_ONLY=0
      shift
      ;;
    --help|-h)
      echo "Usage: $0 [OPTIONS]"
      echo
      echo "Options:"
      echo "  --app-only    Build only the .app bundle in dist/ (no .pkg or .dmg)"
      echo "  --pkg-only    Build only the .pkg installer"
      echo "  --dmg-only    Build only the .dmg disk image"
      echo "  --both        Build both .pkg and .dmg (default)"
      echo "  --help, -h    Show this help message"
      echo
      echo "Environment variables:"
      echo "  BUILD_PKG=0|1          Enable/disable .pkg build (default: 1)"
      echo "  BUILD_DMG=0|1          Enable/disable .dmg build (default: 1)"
      echo "  BUILD_APP_ONLY=0|1     Build only .app bundle (default: 0)"
      echo "  PHOTOPRISM_REF=<ref>   Git reference to build (default: latest)"
      echo "  TF_VERSION=<version>   TensorFlow version (default: 2.18.0)"
      echo "  ONNX_VERSION=<version> ONNX Runtime version (default: 1.22.0)"
      echo
      exit 0
      ;;
    *)
      echo "Unknown option: $1"
      echo "Use --help for usage information."
      exit 1
      ;;
  esac
done

# Validate at least one output format is selected
if [[ "$BUILD_PKG" != "1" && "$BUILD_DMG" != "1" && "$BUILD_APP_ONLY" != "1" ]]; then
  echo "!! Error: At least one output format must be selected (--app-only, --pkg-only, --dmg-only, or --both)"
  exit 1
fi

# Configuration
PHOTOPRISM_REF="${PHOTOPRISM_REF:-latest}"
TF_VERSION="${TF_VERSION:-2.18.0}"
INSTALL_TF="${INSTALL_TF:-1}"
ONNX_VERSION="${ONNX_VERSION:-1.22.0}"
INSTALL_ONNX="${INSTALL_ONNX:-1}"
PKG_ID="${PKG_ID:-app.photoprism.server}"
PKG_VERSION="${PKG_VERSION:-}"

# Directories
TEMP_DIR="$SCRIPT_DIR/temp"
DIST_DIR="$SCRIPT_DIR/dist"

# Launcher Swift source
LAUNCHER_SRC="${LAUNCHER_SRC:-$SCRIPT_DIR/PhotoPrismLauncher}"

echo ">> Build configuration:"
if [[ "$BUILD_APP_ONLY" == "1" ]]; then
  echo "   Mode: App bundle only"
else
  echo "   PKG: $([ "$BUILD_PKG" = "1" ] && echo "Yes" || echo "No")"
  echo "   DMG: $([ "$BUILD_DMG" = "1" ] && echo "Yes" || echo "No")"
fi
echo

### --------------------------------------------------------------------
### System checks
### --------------------------------------------------------------------

echo ">> Checking system requirements..."

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "!! This script is for macOS only."
  exit 1
fi

if [[ "$(uname -m)" != "arm64" ]]; then
  echo "!! This script is for Apple Silicon (arm64) Macs only."
  exit 1
fi

### --------------------------------------------------------------------
### Xcode SDK check
### --------------------------------------------------------------------

echo ">> Checking Xcode SDK version..."

SDK_VERSION="$(xcrun --show-sdk-version 2>/dev/null || echo "0")"
SDK_MAJOR="${SDK_VERSION%%.*}"

if [[ "$SDK_MAJOR" -lt 12 ]]; then
  echo
  echo "!! ERROR: macOS SDK version $SDK_VERSION is too old."
  echo "   Go 1.23+ requires SDK 12.0 or newer (macOS Monterey)."
  echo
  echo "   Current SDK: $SDK_VERSION"
  echo "   Required:    12.0+"
  echo
  echo "   To fix this, either:"
  echo
  echo "   1. Install Xcode from the App Store, then run:"
  echo "      sudo xcode-select -s /Applications/Xcode.app/Contents/Developer"
  echo
  echo "   2. Or update Command Line Tools:"
  echo "      sudo rm -rf /Library/Developer/CommandLineTools"
  echo "      xcode-select --install"
  echo
  exit 1
fi

echo "   SDK version: $SDK_VERSION ✓"

### --------------------------------------------------------------------
### Homebrew check and required packages
### --------------------------------------------------------------------

echo ">> Checking Homebrew installation..."

if ! command -v brew &>/dev/null; then
  echo "!! Homebrew is not installed."
  echo "   Install it with:"
  echo '   /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'
  exit 1
fi

echo "   Homebrew found: $(brew --prefix)"

# Required Homebrew packages for PhotoPrism compilation
REQUIRED_BREW_PACKAGES=(
  "go"
  "node"
  "npm"
  "git"
  "make"
  "pkg-config"
  "vips"
  "librsvg"
)

echo ">> Checking required Homebrew packages..."

MISSING_PACKAGES=()
for pkg in "${REQUIRED_BREW_PACKAGES[@]}"; do
  if ! brew list "$pkg" &>/dev/null; then
    MISSING_PACKAGES+=("$pkg")
  else
    echo "   ✓ $pkg"
  fi
done

if [[ ${#MISSING_PACKAGES[@]} -gt 0 ]]; then
  echo
  echo "!! Missing required packages: ${MISSING_PACKAGES[*]}"
  echo "   Install them with:"
  echo "   brew install ${MISSING_PACKAGES[*]}"
  echo
  read -p "   Do you want to install them now? [y/N] " -n 1 -r
  echo
  if [[ $REPLY =~ ^[Yy]$ ]]; then
    echo ">> Installing missing packages..."
    brew install "${MISSING_PACKAGES[@]}"
  else
    echo "!! Cannot continue without required packages."
    exit 1
  fi
fi

### --------------------------------------------------------------------
### Required system commands
### --------------------------------------------------------------------

echo ">> Checking required system commands..."

REQUIRED_COMMANDS=(
  "git"
  "go"
  "node"
  "npm"
  "make"
  "curl"
  "tar"
  "pkgbuild"
  "codesign"
  "swiftc"
  "sips"
  "iconutil"
  "hdiutil"
)

for cmd in "${REQUIRED_COMMANDS[@]}"; do
  if ! command -v "$cmd" &>/dev/null; then
    echo "!! Required command not found: $cmd"
    exit 1
  fi
done

echo "   All required commands available."

### --------------------------------------------------------------------
### Preparation
### --------------------------------------------------------------------

echo ">> Creating directories..."
mkdir -p "$TEMP_DIR" "$DIST_DIR"
cd "$TEMP_DIR"

### --------------------------------------------------------------------
### Download PhotoPrism icon (SVG -> PNG)
### --------------------------------------------------------------------

echo ">> Downloading PhotoPrism icon..."
ICON_SVG="$TEMP_DIR/photoprism_logo.svg"
ICON_PNG="$TEMP_DIR/photoprism_icon_1024.png"

if [[ ! -f "$ICON_PNG" ]]; then
  if curl -fsSL "https://dl.photoprism.app/img/logo/logo.svg" -o "$ICON_SVG" 2>/dev/null; then
    echo "   SVG logo downloaded"
    if command -v rsvg-convert &>/dev/null; then
      rsvg-convert -w 1024 -h 1024 "$ICON_SVG" -o "$ICON_PNG"
      echo "   Converted with rsvg-convert"
    elif command -v qlmanage &>/dev/null; then
      qlmanage -t -s 1024 -o "$TEMP_DIR" "$ICON_SVG" 2>/dev/null || true
      [[ -f "$TEMP_DIR/photoprism_logo.svg.png" ]] && mv "$TEMP_DIR/photoprism_logo.svg.png" "$ICON_PNG"
    elif command -v convert &>/dev/null; then
      convert -background none -density 300 -resize 1024x1024 "$ICON_SVG" "$ICON_PNG"
    else
      echo "!! No SVG conversion tool available."
      ICON_PNG=""
    fi
  fi
fi

### --------------------------------------------------------------------
### Clone PhotoPrism repository
### --------------------------------------------------------------------

if [[ -d photoprism/.git ]]; then
  echo ">> PhotoPrism repository already exists, updating..."
  cd photoprism && git fetch --all --tags
else
  echo ">> Cloning PhotoPrism repository..."
  git clone https://github.com/photoprism/photoprism.git
  cd photoprism
fi

### --------------------------------------------------------------------
### Resolve Git reference
### --------------------------------------------------------------------

RESOLVED_REF="$PHOTOPRISM_REF"
if [[ "$PHOTOPRISM_REF" == "latest" ]]; then
  echo ">> Finding latest stable release..."
  API_JSON="$(curl -fsSL https://api.github.com/repos/photoprism/photoprism/releases/latest || true)"
  if [[ -n "$API_JSON" ]]; then
    TAG="$(echo "$API_JSON" | grep '"tag_name"' | head -1 | sed -E 's/.*"tag_name"[[:space:]]*:[[:space:]]*"([^"]+)".*/\1/')"
    if [[ -n "$TAG" ]]; then
      RESOLVED_REF="$TAG"
      echo "   Latest release: $RESOLVED_REF"
    fi
  fi
  if [[ "$RESOLVED_REF" == "latest" ]]; then
    RESOLVED_REF="develop"
    echo "   No release found, using develop branch"
  fi
fi

echo ">> Checking out $RESOLVED_REF..."
git checkout "$RESOLVED_REF" 2>/dev/null || git checkout -b "$RESOLVED_REF" "origin/$RESOLVED_REF" 2>/dev/null || true

# Get version from Git
GIT_VERSION="$(git describe --tags --always 2>/dev/null || echo "dev")"
if [[ -z "$PKG_VERSION" ]]; then
  PKG_VERSION="$GIT_VERSION"
fi
echo "   Version: $PKG_VERSION"

cd "$TEMP_DIR"

### --------------------------------------------------------------------
### Download TensorFlow (optional)
### --------------------------------------------------------------------

TF_DEST="$TEMP_DIR/tensorflow"
if [[ "$INSTALL_TF" == "1" ]]; then
  TF_TARBALL="libtensorflow-cpu-darwin-arm64.tar.gz"
  TF_URL="https://storage.googleapis.com/tensorflow/versions/${TF_VERSION}/${TF_TARBALL}"
  
  if [[ ! -d "$TF_DEST/lib" ]]; then
    echo ">> Downloading TensorFlow $TF_VERSION..."
    echo "   Note: If this fails, find the latest version at https://github.com/tensorflow/tensorflow/releases"
    echo "         and update this script -run after with: TF_VERSION=<version> $0"
    mkdir -p "$TF_DEST"
    curl -fSL "$TF_URL" -o "$TEMP_DIR/$TF_TARBALL"
    tar -xzf "$TEMP_DIR/$TF_TARBALL" -C "$TF_DEST"
    rm -f "$TEMP_DIR/$TF_TARBALL"
  else
    echo ">> TensorFlow already downloaded."
  fi
fi

### --------------------------------------------------------------------
### Download ONNX Runtime (optional)
### --------------------------------------------------------------------

ONNX_DEST=""
if [[ "$INSTALL_ONNX" == "1" ]]; then
  ONNX_DIR="onnxruntime-osx-arm64-${ONNX_VERSION}"
  ONNX_TARBALL="${ONNX_DIR}.tgz"
  ONNX_URL="https://github.com/microsoft/onnxruntime/releases/download/v${ONNX_VERSION}/${ONNX_TARBALL}"

  if [[ ! -d "$TEMP_DIR/$ONNX_DIR" ]]; then
    echo ">> Downloading ONNX Runtime $ONNX_VERSION..."
    curl -fSL "$ONNX_URL" -o "$TEMP_DIR/$ONNX_TARBALL"
    tar -xzf "$TEMP_DIR/$ONNX_TARBALL" -C "$TEMP_DIR"
    rm -f "$TEMP_DIR/$ONNX_TARBALL"
  else
    echo ">> ONNX Runtime already downloaded."
  fi
  ONNX_DEST="$TEMP_DIR/$ONNX_DIR"
fi

### --------------------------------------------------------------------
### Download ExifTool
### --------------------------------------------------------------------

EXIFTOOL_VERSION="${EXIFTOOL_VERSION:-13.43}"
EXIFTOOL_DEST="$TEMP_DIR/exiftool"

if [[ ! -f "$EXIFTOOL_DEST/exiftool" ]]; then
  echo ">> Downloading ExifTool $EXIFTOOL_VERSION..."
  EXIFTOOL_TARBALL="Image-ExifTool-${EXIFTOOL_VERSION}.tar.gz"
  EXIFTOOL_URL="https://sourceforge.net/projects/exiftool/files/${EXIFTOOL_TARBALL}/download"

  mkdir -p "$EXIFTOOL_DEST"
  curl -fSL "$EXIFTOOL_URL" -o "$TEMP_DIR/$EXIFTOOL_TARBALL"
  tar -xzf "$TEMP_DIR/$EXIFTOOL_TARBALL" -C "$TEMP_DIR"

  EXIFTOOL_EXTRACTED="$TEMP_DIR/Image-ExifTool-${EXIFTOOL_VERSION}"

  # Copy the exiftool script and lib directory
  cp "$EXIFTOOL_EXTRACTED/exiftool" "$EXIFTOOL_DEST/"
  cp -R "$EXIFTOOL_EXTRACTED/lib" "$EXIFTOOL_DEST/"
  chmod +x "$EXIFTOOL_DEST/exiftool"

  rm -f "$TEMP_DIR/$EXIFTOOL_TARBALL"
  rm -rf "$EXIFTOOL_EXTRACTED"
  echo "   ExifTool installed to: $EXIFTOOL_DEST"
else
  echo ">> ExifTool already downloaded."
fi

### --------------------------------------------------------------------
### Download FFmpeg
### --------------------------------------------------------------------

FFMPEG_VERSION="${FFMPEG_VERSION:-7.1}"
FFMPEG_DEST="$TEMP_DIR/ffmpeg"

if [[ ! -f "$FFMPEG_DEST/ffmpeg" ]]; then
  echo ">> Downloading FFmpeg $FFMPEG_VERSION for macOS ARM64..."

  # FFmpeg static build for macOS ARM64
  # Using evermeet.cx builds which are well-maintained for macOS
  FFMPEG_URL="https://evermeet.cx/ffmpeg/getrelease/ffmpeg/zip"
  FFPROBE_URL="https://evermeet.cx/ffmpeg/getrelease/ffprobe/zip"

  mkdir -p "$FFMPEG_DEST"

  # Download ffmpeg
  echo "   Downloading ffmpeg binary..."
  curl -fSL "$FFMPEG_URL" -o "$TEMP_DIR/ffmpeg.zip"
  unzip -q "$TEMP_DIR/ffmpeg.zip" -d "$FFMPEG_DEST"
  chmod +x "$FFMPEG_DEST/ffmpeg"

  # Download ffprobe
  echo "   Downloading ffprobe binary..."
  curl -fSL "$FFPROBE_URL" -o "$TEMP_DIR/ffprobe.zip"
  unzip -q "$TEMP_DIR/ffprobe.zip" -d "$FFMPEG_DEST"
  chmod +x "$FFMPEG_DEST/ffprobe"

  # Cleanup
  rm -f "$TEMP_DIR/ffmpeg.zip" "$TEMP_DIR/ffprobe.zip"

  echo "   FFmpeg installed to: $FFMPEG_DEST"
  echo "   FFmpeg version:"
  "$FFMPEG_DEST/ffmpeg" -version | head -1
else
  echo ">> FFmpeg already downloaded."
fi

### --------------------------------------------------------------------
### Build PhotoPrism
### --------------------------------------------------------------------

cd "$TEMP_DIR/photoprism"

echo ">> Installing dependencies..."
make dep

echo ">> Building frontend..."
make build-js

echo ">> Building backend..."
TF_LIB="${TF_DEST}/lib"
TF_INCLUDE="${TF_DEST}/include"

# Detect macOS version - the resulting binary will only work on this version or newer
MACOS_MAJOR="$(sw_vers -productVersion | cut -d. -f1)"
MACOS_MINOR="$(sw_vers -productVersion | cut -d. -f2)"
MIN_MACOS_VERSION="${MACOS_MAJOR}.0"

echo "   Detected macOS ${MACOS_MAJOR}.${MACOS_MINOR}"
echo "   NOTE: The resulting package will require macOS ${MIN_MACOS_VERSION} or newer"

export MACOSX_DEPLOYMENT_TARGET="${MIN_MACOS_VERSION}"
export CGO_CFLAGS="-mmacosx-version-min=${MIN_MACOS_VERSION} -I${TF_INCLUDE}"
export CGO_LDFLAGS="-mmacosx-version-min=${MIN_MACOS_VERSION} -L${TF_LIB} -ltensorflow -ltensorflow_framework -Wl,-rpath,${TF_LIB}"
export LIBRARY_PATH="${TF_LIB}:${LIBRARY_PATH:-}"
make build-go

### --------------------------------------------------------------------
### Compile Swift launcher
### --------------------------------------------------------------------

echo ">> Compiling Swift launcher..."
LAUNCHER_SWIFT="$LAUNCHER_SRC/AppDelegate.swift"

if [[ ! -f "$LAUNCHER_SWIFT" ]]; then
  echo "!! AppDelegate.swift not found in $LAUNCHER_SRC"
  exit 1
fi

LAUNCHER_BUILD="$TEMP_DIR/launcher_build"
rm -rf "$LAUNCHER_BUILD" && mkdir -p "$LAUNCHER_BUILD"

swiftc \
  -O \
  -parse-as-library \
  -sdk "$(xcrun --show-sdk-path)" \
  -target arm64-apple-macos${MACOS_MAJOR}.0 \
  -framework Cocoa \
  -o "$LAUNCHER_BUILD/PhotoPrism" \
  "$LAUNCHER_SWIFT"

echo "   Launcher compiled: $LAUNCHER_BUILD/PhotoPrism"

### --------------------------------------------------------------------
### Create PhotoPrism.app bundle
### --------------------------------------------------------------------

echo ">> Creating PhotoPrism.app bundle..."
APP_NAME="PhotoPrism.app"
APP_DIR="$TEMP_DIR/$APP_NAME"
APP_CONTENTS="$APP_DIR/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_FRAMEWORKS="$APP_CONTENTS/Frameworks"

rm -rf "$APP_DIR"
mkdir -p "$APP_MACOS" "$APP_RESOURCES" "$APP_FRAMEWORKS"

# Copy launcher and server
cp "$LAUNCHER_BUILD/PhotoPrism" "$APP_MACOS/"
cp "$TEMP_DIR/photoprism/photoprism" "$APP_MACOS/photoprism-server"
chmod +x "$APP_MACOS/PhotoPrism" "$APP_MACOS/photoprism-server"

# Copy ExifTool
if [[ -f "$EXIFTOOL_DEST/exiftool" ]]; then
  echo ">> Copying ExifTool to bundle..."
  cp "$EXIFTOOL_DEST/exiftool" "$APP_MACOS/"
  cp -R "$EXIFTOOL_DEST/lib" "$APP_MACOS/"
  chmod +x "$APP_MACOS/exiftool"
  echo "   ExifTool added to bundle"
fi

# Copy FFmpeg
if [[ -f "$FFMPEG_DEST/ffmpeg" ]]; then
  echo ">> Copying FFmpeg to bundle..."
  cp "$FFMPEG_DEST/ffmpeg" "$APP_MACOS/"
  cp "$FFMPEG_DEST/ffprobe" "$APP_MACOS/"
  chmod +x "$APP_MACOS/ffmpeg" "$APP_MACOS/ffprobe"
  echo "   FFmpeg and FFprobe added to bundle"
fi

# Assets
[[ -d "$TEMP_DIR/photoprism/assets" ]] && cp -R "$TEMP_DIR/photoprism/assets" "$APP_RESOURCES/"

# TensorFlow libs
cp "$TF_LIB"/libtensorflow*.dylib "$APP_FRAMEWORKS/"

### --------------------------------------------------------------------
### Generate .icns icon
### --------------------------------------------------------------------

if [[ -n "$ICON_PNG" && -f "$ICON_PNG" ]]; then
  echo ">> Generating icon..."
  ICONSET="$TEMP_DIR/AppIcon.iconset"
  rm -rf "$ICONSET" && mkdir -p "$ICONSET"
  
  sips -z 16 16 "$ICON_PNG" --out "$ICONSET/icon_16x16.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_16x16@2x.png" >/dev/null
  sips -z 32 32 "$ICON_PNG" --out "$ICONSET/icon_32x32.png" >/dev/null
  sips -z 64 64 "$ICON_PNG" --out "$ICONSET/icon_32x32@2x.png" >/dev/null
  sips -z 128 128 "$ICON_PNG" --out "$ICONSET/icon_128x128.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_128x128@2x.png" >/dev/null
  sips -z 256 256 "$ICON_PNG" --out "$ICONSET/icon_256x256.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_256x256@2x.png" >/dev/null
  sips -z 512 512 "$ICON_PNG" --out "$ICONSET/icon_512x512.png" >/dev/null
  sips -z 1024 1024 "$ICON_PNG" --out "$ICONSET/icon_512x512@2x.png" >/dev/null
  
  iconutil -c icns "$ICONSET" -o "$APP_RESOURCES/AppIcon.icns"
  rm -rf "$ICONSET"
fi

### --------------------------------------------------------------------
### Bundle libvips + Homebrew dependencies
### --------------------------------------------------------------------

echo ">> Bundling libvips and dependencies..."
VIPS_PATH="$(otool -L "$TEMP_DIR/photoprism/photoprism" | awk '/libvips.*dylib/ {print $1; exit}')"

if [[ -n "$VIPS_PATH" ]]; then
  declare -a TO_PROCESS=("$VIPS_PATH")
  SEEN=""

  while ((${#TO_PROCESS[@]} > 0)); do
    cur="${TO_PROCESS[0]}"
    TO_PROCESS=("${TO_PROCESS[@]:1}")
    
    [[ " $SEEN " == *" $cur "* ]] && continue
    SEEN+=" $cur"

    if [[ "$cur" == /opt/homebrew/* ]]; then
      base="$(basename "$cur")"
      if [[ ! -f "$APP_FRAMEWORKS/$base" ]]; then
        cp "$cur" "$APP_FRAMEWORKS/$base"
        chmod +x "$APP_FRAMEWORKS/$base"
        install_name_tool -id "@rpath/$base" "$APP_FRAMEWORKS/$base" 2>/dev/null || true
      fi
    fi

    cur_dir="$(dirname "$cur")"
    while read -r dep _; do
      [[ -z "$dep" || "$dep" == "$cur" ]] && continue
      if [[ "$dep" == /opt/homebrew/* ]]; then
        TO_PROCESS+=("$dep")
      elif [[ "$dep" == @rpath/* ]]; then
        base="${dep#@rpath/}"
        if [[ -f "$cur_dir/$base" ]]; then
          TO_PROCESS+=("$cur_dir/$base")
        else
          found="$(/usr/bin/find /opt/homebrew -maxdepth 7 -type f -name "$base" -print -quit 2>/dev/null || true)"
          [[ -n "$found" ]] && TO_PROCESS+=("$found")
        fi
      elif [[ "$dep" == @loader_path/* ]]; then
        rel="${dep#@loader_path/}"
        [[ -f "$cur_dir/$rel" ]] && TO_PROCESS+=("$cur_dir/$rel")
      fi
    done < <(otool -L "$cur" 2>/dev/null | awk 'NR>1 {print $1}')
  done

  # Rewrite library paths
  for bin in "$APP_MACOS/photoprism-server" "$APP_FRAMEWORKS"/*.dylib; do
    [[ -f "$bin" ]] || continue
    while read -r dep _; do
      [[ "$dep" != /opt/homebrew/* ]] && continue
      base="$(basename "$dep")"
      [[ -f "$APP_FRAMEWORKS/$base" ]] && install_name_tool -change "$dep" "@rpath/$base" "$bin" 2>/dev/null || true
    done < <(otool -L "$bin" 2>/dev/null | awk 'NR>1 {print $1}')
  done
  
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP_MACOS/photoprism-server" 2>/dev/null || true
fi

### --------------------------------------------------------------------
### ONNX Runtime
### --------------------------------------------------------------------

if [[ -n "$ONNX_DEST" && -d "$ONNX_DEST" ]]; then
  echo ">> Copying ONNX Runtime..."
  ONNX_LIB="$ONNX_DEST/lib"
  [[ ! -d "$ONNX_LIB" ]] && ONNX_LIB="$ONNX_DEST"
  cp "$ONNX_LIB"/libonnxruntime*.dylib "$APP_FRAMEWORKS/" 2>/dev/null || true
  
  if onnx_real=$(cd "$APP_FRAMEWORKS" && ls libonnxruntime*.dylib 2>/dev/null | head -n1); then
    (cd "$APP_FRAMEWORKS" && for n in libonnxruntime.so libonnxruntime.so.1; do ln -sf "$onnx_real" "$n" 2>/dev/null || true; done)
  fi
fi

### --------------------------------------------------------------------
### Info.plist
### --------------------------------------------------------------------

cat > "$APP_CONTENTS/Info.plist" << EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleName</key><string>PhotoPrism</string>
  <key>CFBundleDisplayName</key><string>PhotoPrism</string>
  <key>CFBundleIdentifier</key><string>${PKG_ID}</string>
  <key>CFBundleVersion</key><string>${PKG_VERSION}</string>
  <key>CFBundleShortVersionString</key><string>${PKG_VERSION}</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleExecutable</key><string>PhotoPrism</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundleIconName</key><string>AppIcon</string>
  <key>LSMinimumSystemVersion</key><string>${MIN_MACOS_VERSION}</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.photography</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>Copyright © 2025 PhotoPrism Contributors</string>
</dict>
</plist>
EOF

echo -n "APPL????" > "$APP_CONTENTS/PkgInfo"

### --------------------------------------------------------------------
### Code signing
### --------------------------------------------------------------------

echo ">> Ad-hoc signing..."
codesign --force --deep --sign - "$APP_DIR"

### --------------------------------------------------------------------
### Copy .app to dist/ (for --app-only mode)
### --------------------------------------------------------------------

if [[ "$BUILD_APP_ONLY" == "1" ]]; then
  echo ">> Copying app to dist/..."
  DIST_APP_PATH="$DIST_DIR/$APP_NAME"
  rm -rf "$DIST_APP_PATH"
  cp -R "$APP_DIR" "$DIST_APP_PATH"
  echo "   App copied: $DIST_APP_PATH"
fi

### --------------------------------------------------------------------
### Create .pkg installer
### --------------------------------------------------------------------

PKG_PATH=""
if [[ "$BUILD_PKG" == "1" ]]; then
  echo ">> Creating .pkg installer..."
  PKG_ROOT="$TEMP_DIR/pkgroot"
  rm -rf "$PKG_ROOT" && mkdir -p "$PKG_ROOT/Applications"
  cp -R "$APP_DIR" "$PKG_ROOT/Applications/"
  codesign --force --deep --sign - "$PKG_ROOT/Applications/$APP_NAME"

  PKG_PATH="$DIST_DIR/PhotoPrism-${PKG_VERSION}.pkg"
  pkgbuild \
    --root "$PKG_ROOT" \
    --identifier "$PKG_ID" \
    --version "$PKG_VERSION" \
    --install-location "/" \
    "$PKG_PATH"

  echo "   PKG created: $PKG_PATH"
else
  echo ">> Skipping .pkg creation (disabled)"
fi

### --------------------------------------------------------------------
### Create .dmg installer
### --------------------------------------------------------------------

DMG_PATH=""
if [[ "$BUILD_DMG" == "1" ]]; then
  echo ">> Creating .dmg installer..."

  DMG_VOLUME_NAME="PhotoPrism"
  DMG_FILENAME="PhotoPrism-${PKG_VERSION}"
  DMG_TEMP="$TEMP_DIR/dmg_temp"
  DMG_PATH="$DIST_DIR/${DMG_FILENAME}.dmg"
  DMG_TEMP_PATH="$TEMP_DIR/${DMG_FILENAME}-temp.dmg"

  # Clean and create temp folder
  rm -rf "$DMG_TEMP"
  mkdir -p "$DMG_TEMP"

  # Copy app to temp folder
  cp -R "$APP_DIR" "$DMG_TEMP/"

  # Create symbolic link to Applications folder
  ln -s /Applications "$DMG_TEMP/Applications"

  # Remove old dmg files if they exist
  rm -f "$DMG_TEMP_PATH" "$DMG_PATH"

  # Unmount if already mounted
  hdiutil detach "/Volumes/$DMG_VOLUME_NAME" 2>/dev/null || true

  # Create temporary read-write DMG
  echo "   Creating temporary DMG..."
  hdiutil create \
    -volname "$DMG_VOLUME_NAME" \
    -srcfolder "$DMG_TEMP" \
    -ov \
    -format UDRW \
    "$DMG_TEMP_PATH"

  # Mount DMG to customize
  echo "   Mounting DMG for customization..."
  MOUNT_OUTPUT=$(hdiutil attach "$DMG_TEMP_PATH" -readwrite -noverify -noautoopen 2>&1)
  echo "$MOUNT_OUTPUT"
  
  # Extract the actual mount point from hdiutil output
  MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -o '/Volumes/[^"]*' | head -1)
  
  if [[ -z "$MOUNT_POINT" || ! -d "$MOUNT_POINT" ]]; then
    MOUNT_POINT="/Volumes/$DMG_VOLUME_NAME"
  fi
  
  echo "   Mount point: $MOUNT_POINT"

  # Set icon positions using Finder (more reliable approach)
 echo "   Configuring DMG layout..."

# Ouvre la fenêtre Finder du volume
open "$MOUNT_POINT"
sleep 2

osascript << EOF || echo "   Note: Could not set custom layout (non-fatal)"
tell application "Finder"
    activate

    -- On suppose que la fenêtre du DMG est maintenant la fenêtre frontale
    set dmgWindow to front window

    -- Vue en icônes + fenêtre sans barre d’outils / de statut
    set current view of dmgWindow to icon view
    set toolbar visible of dmgWindow to false
    set statusbar visible of dmgWindow to false
    set bounds of dmgWindow to {100, 100, 640, 480}

    -- Options d’affichage des icônes
    set viewOptions to the icon view options of dmgWindow
    set arrangement of viewOptions to not arranged
    set icon size of viewOptions to 128 -- icônes plus grandes

    -- Position des icônes
    set position of item "PhotoPrism.app" of dmgWindow to {140, 180}
    set position of item "Applications" of dmgWindow to {400, 180}

    delay 1
    close dmgWindow
end tell
EOF





  # Set custom volume icon
  if [[ -f "$APP_RESOURCES/AppIcon.icns" ]]; then
    cp "$APP_RESOURCES/AppIcon.icns" "$MOUNT_POINT/.VolumeIcon.icns"
    SetFile -c icnC "$MOUNT_POINT/.VolumeIcon.icns" 2>/dev/null || true
    SetFile -a C "$MOUNT_POINT" 2>/dev/null || true
  fi

  # Ensure changes are written
  sync
  sleep 2

  # Unmount
  echo "   Unmounting..."
  hdiutil detach "$MOUNT_POINT" || hdiutil detach "$MOUNT_POINT" -force

  # Convert to compressed read-only DMG
  echo "   Compressing DMG..."
  hdiutil convert "$DMG_TEMP_PATH" -format UDZO -imagekey zlib-level=9 -o "$DMG_PATH"

  # Cleanup temp DMG
  rm -f "$DMG_TEMP_PATH"
  rm -rf "$DMG_TEMP"

  echo "   DMG created: $DMG_PATH"
else
  echo ">> Skipping .dmg creation (disabled)"
fi

### --------------------------------------------------------------------
### Summary
### --------------------------------------------------------------------

echo
echo "==============================================="
echo "Build complete!"
echo

if [[ "$BUILD_APP_ONLY" == "1" ]]; then
  echo "Application bundle:"
  echo "  App: $DIST_DIR/$APP_NAME"
  echo
  echo "To use:"
  echo "  - Copy to /Applications manually"
  echo "  - Or double-click to run from $DIST_DIR"
elif [[ "$BUILD_PKG" == "1" || "$BUILD_DMG" == "1" ]]; then
  echo "Installers:"
  [[ -n "$PKG_PATH" ]] && echo "  PKG: $PKG_PATH"
  [[ -n "$DMG_PATH" ]] && echo "  DMG: $DMG_PATH"
  echo
  echo "Installation:"
  [[ "$BUILD_PKG" == "1" ]] && echo "  PKG: Double-click to run installer"
  [[ "$BUILD_DMG" == "1" ]] && echo "  DMG: Open and drag PhotoPrism to Applications"
fi

echo
echo "Minimum macOS version: ${MIN_MACOS_VERSION}"
echo
echo "Temp folder: $TEMP_DIR"
echo "Dist folder: $DIST_DIR"
echo
echo "Default login: admin / photoprism"
echo "==============================================="