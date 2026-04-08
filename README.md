# PureMac

A free, open-source macOS cleaning utility. Keep your Mac fast, clean, and optimized.

![macOS](https://img.shields.io/badge/macOS-13.0+-blue)
![Swift](https://img.shields.io/badge/Swift-5.9-orange)
![License](https://img.shields.io/badge/License-MIT-green)

## Features

- **Smart Scan** - Scan all categories at once with a single click
- **System Junk** - Clean system caches, logs, and temporary files
- **User Cache** - Remove application caches and browser data
- **Mail Attachments** - Clear downloaded mail attachments
- **Trash Bins** - Empty your Trash
- **Large & Old Files** - Find files over 100 MB or older than 1 year
- **Purgeable Space** - Purge APFS purgeable disk space
- **Xcode Junk** - Clean derived data, archives, and simulator caches
- **Homebrew Cache** - Clear Homebrew download cache
- **Scheduled Cleaning** - Automatic scans on configurable intervals (hours/days/weeks)
- **Auto-Purge** - Automatically purge purgeable files on schedule

## Screenshots

The app features a dark, modern UI inspired by professional Mac utilities:

- Dark gradient theme with vibrant accent colors
- Animated circular scan progress indicator
- Sidebar navigation with real-time size indicators
- Disk usage overview bar

## Requirements

- macOS 13.0 (Ventura) or later
- Xcode 15+ (for building from source)
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (for project generation)

## Building

```bash
# Install XcodeGen if you don't have it
brew install xcodegen

# Clone the repo
git clone https://github.com/momenbasel/PureMac.git
cd PureMac

# Generate Xcode project
xcodegen generate

# Build
xcodebuild -project PureMac.xcodeproj -scheme PureMac -configuration Release build

# Or open in Xcode
open PureMac.xcodeproj
```

The built app will be at `build/Build/Products/Release/PureMac.app`.

## Scheduling

PureMac supports automatic cleaning on configurable intervals:

1. Open **Settings** (gear icon or Cmd+,)
2. Go to the **Schedule** tab
3. Enable **Automatic Cleaning**
4. Choose your preferred interval (every hour to monthly)
5. Optionally enable **Auto-clean after scan** and **Auto-purge purgeable space**

The scheduler runs while the app is open. A LaunchAgent can be installed for background scheduling.

## What Gets Cleaned

| Category | Paths |
|---|---|
| System Junk | `/Library/Caches`, `/Library/Logs`, `/tmp`, `~/Library/Logs` |
| User Cache | `~/Library/Caches`, npm/pip/yarn/pnpm caches |
| Mail Attachments | `~/Library/Mail Downloads` |
| Trash | `~/.Trash` |
| Large Files | `~/Downloads`, `~/Documents`, `~/Desktop` (>100MB or >1yr old) |
| Purgeable | APFS purgeable space via `diskutil` |
| Xcode | `DerivedData`, `Archives`, `CoreSimulator/Caches` |
| Homebrew | `~/Library/Caches/Homebrew` |

## Safety

- Never deletes system-critical files
- Only removes caches, logs, temporary files, and user-selected items
- Large & Old Files are **not auto-selected** - you choose what to remove
- All operations are non-destructive to the operating system

## License

MIT License. See [LICENSE](LICENSE) for details.
