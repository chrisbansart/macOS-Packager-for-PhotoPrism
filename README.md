- # PhotoPrism Server and Launcher for macOS

  A native MacOS PhotoPrism server and launcher application for PhotoPrism

  ## Features

  - **Embed PhotoPrism server and the launcher** in one MacOS app "PhotoPrism"
  - **Native macOS window**: Clean interface to manage your PhotoPrism server
  - **Start/Stop Server**: Start and stop the PhotoPrism server with one click
  - **Open Web UI**: Automatically opens the web interface (http://localhost:2342)
  - **Show Logs**: View server logs
  - **Open Pictures Folder**: Quick access to your photos (originals and imports)
  - **Open Data Folder**: Access to application data (cache, database, etc.)
  - **Preferences**: Configure custom folders and auto-start options
  - **Official PhotoPrism icon**: Uses the official PhotoPrism logo
  - **Complete bundle**: Includes FFmpeg for video processing, ExifTool for metadata extraction

  ## Project Structure

  ```
  PhotoPrismLauncher/
  ├── PhotoPrismLauncher/
  │   └── AppDelegate.swift          # Main application code
  ├── build-launcher.sh              # Standalone launcher build
  ├── build-photoprism-installer-with-launcher.sh  # Full build script
  └── README.md
  ```

  ## Usage

  ### Full Build (Recommended)

  This script clones PhotoPrism, compiles it, builds the launcher, bundles all dependencies, and creates a .pkg installer:

  ```bash
  chmod +x build-photoprism-installer-with-launcher.sh
  ./build-photoprism-installer-with-launcher.sh ### Build both PKG and DMG
  or with options:
  ./build-photoprism-installer-with-launcher.sh --pkg-only   # PKG only
  ./build-photoprism-installer-with-launcher.sh --dmg-only   # DMG only
  ./build-photoprism-installer-with-launcher.sh --help       # Help
  ```

./build-photoprism-installer-with-launcher.sh # Les deux

The script automatically:

- Checks for required dependencies (Homebrew, Xcode SDK, etc.)
- Downloads TensorFlow and ONNX Runtime libraries
- Downloads FFmpeg and FFprobe (video processing)
- Downloads ExifTool (metadata extraction)
- Clones and compiles PhotoPrism
- Downloads the official PhotoPrism logo and generates icons
- Builds the native Swift launcher
- Bundles all dylibs with corrected rpaths
- Creates a .pkg installer
- Creates a .dmg installer

### Usage

**Prerequisites**:

```bash
# Install Homebrew if not already installed
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"

# Required packages (the script will prompt to install missing ones)
brew install go node npm git make pkg-config vips librsvg
```

### Build Output

```
PhotoPrismLauncher/
├── temp/                    # Temporary build files
│   ├── photoprism/          # PhotoPrism source
│   ├── tensorflow/          # TensorFlow libraries
│   ├── onnxruntime-*/       # ONNX Runtime libraries
│   └── PhotoPrism.app/      # Built application
└── dist/                    # Final output
    └── PhotoPrism-{version}.pkg
```

## Default Data Locations

- **Pictures**: `~/Pictures/PhotoPrism/`
  - `originals/`: Original photos
  - `import/`: Import folder
- **Application Data**: `~/Library/Application Support/PhotoPrism/`
  - `storage/`: Database, cache, thumbnails, etc.
  - `storage/config/`: Configuration files
- **Logs**: `~/Library/Logs/PhotoPrism/photoprism.log`

These paths can be customized in **Preferences** (⌘,).

## Default Credentials of PhotoPrism server

- **Username**: `admin`
- **Password**: `photoprism`

⚠️ **Change the password after first login!**

## System Requirements

- macOS 12.0 (Monterey) or newer
- Apple Silicon (M1/M2/M3/M4)
- Xcode Command Line Tools with SDK 12.0+
- Homebrew

To check your SDK version:

```bash
xcrun --show-sdk-version
```

If the SDK is outdated, update Xcode or Command Line Tools:

```bash
sudo rm -rf /Library/Developer/CommandLineTools
xcode-select --install
```

## Application Bundle Structure

```
PhotoPrism.app/
└── Contents/
    ├── Info.plist
    ├── PkgInfo
    ├── MacOS/
    │   ├── PhotoPrism           # Swift launcher (main executable)
    │   ├── photoprism-server    # PhotoPrism server binary
    │   ├── ffmpeg               # FFmpeg video processor
    │   ├── ffprobe              # FFprobe metadata reader
    │   ├── exiftool             # ExifTool metadata extractor
    │   └── lib/                 # ExifTool libraries
    ├── Resources/
    │   ├── AppIcon.icns         # Application icon
    │   └── assets/              # PhotoPrism web assets
    └── Frameworks/
        ├── libtensorflow*.dylib      # TensorFlow
        ├── libonnxruntime*.dylib     # ONNX Runtime
        ├── libvips*.dylib            # Image processing
        ├── libheif*.dylib            # HEIF support
        └── ...                       # Other dependencies
```

## Preferences

Access preferences with **⌘,** or via the menu **PhotoPrism Launcher > Preferences...**

- **Pictures Folder**: Where your photos are stored (originals and imports)
- **Data Folder**: Where PhotoPrism stores its data (database, cache, etc.)
- **Start server when app launches**: Automatically start the server on app launch

## Customization

### Change the Port

Modify the `PHOTOPRISM_HTTP_PORT` environment variable in `AppDelegate.swift` in the `startServer()` function.

### Add Environment Variables

Add entries to the `environment` dictionary in the `startServer()` function in `AppDelegate.swift`.

## Troubleshooting

### Port 2342 already in use

**New Feature**: The launcher now automatically detects if port 2342 is in use and offers options:
- **Stop Existing Process**: Automatically kills the existing process and starts fresh
- **Open Existing Server**: Simply opens the browser to the existing server
- **Cancel**: Cancels the operation

### Application shutdown guarantees

**New Feature**: The application uses a 4-stage progressive shutdown system to ensure all PhotoPrism processes terminate properly when you:
- Quit the application (⌘Q)
- Click "Stop Server"

The 4 stages are:
1. Graceful shutdown via `photoprism stop`
2. SIGTERM to process group
3. SIGKILL to process group
4. Nuclear option (kill by port + name)

After quitting, verify no processes remain:
```bash
ps aux | grep photoprism | grep -v grep  # Should be empty
lsof -i :2342                            # Should be empty
```

### Manual process management

Use the helper script for interactive process management:
```bash
./scripts/kill-photoprism.sh
```

Or use the nuclear option one-liner:
```bash
(lsof -ti :2342 | xargs kill -9 2>/dev/null; pkill -9 -i photoprism 2>/dev/null) && echo "✓ Done"
```

### Server won't start

- Check logs: Click "Show Logs" button
- Verify folders exist and are writable
- See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for detailed solutions

### Technical documentation

- **Process Management**: See [PROCESS_MANAGEMENT.md](PROCESS_MANAGEMENT.md) for technical details on the shutdown system
- **FFmpeg Integration**: See [FFMPEG_INTEGRATION.md](FFMPEG_INTEGRATION.md) for video processing details
- **Live Photos**: See [LIVE_PHOTOS.md](LIVE_PHOTOS.md) for Apple Live Photos and Android Motion Photos support

### Build fails with SDK error

- Update Xcode Command Line Tools (see System Requirements)
- Ensure SDK version is 12.0 or newer

### Missing libraries at runtime

- The build script bundles all required dylibs
- Check `Contents/Frameworks/` in the app bundle

For more issues, see the comprehensive [Troubleshooting Guide](TROUBLESHOOTING.md).

## License

This project is licensed under the **GNU General Public License v3.0** - see the [LICENSE](LICENSE) file for details.

## Author

Chris Bansart ([@chrisbansart](https://github.com/chrisbansart))

## Credits

- [PhotoPrism](https://photoprism.app) - AI-Powered Photos App
- [Jellyfin Server for macOS](https://github.com/jellyfin/jellyfin-server-macos) - Architecture inspiration
- [TensorFlow](https://www.tensorflow.org/) - Machine learning framework
- [libvips](https://libvips.github.io/libvips/) - Image processing library
