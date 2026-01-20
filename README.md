# MITM Menu Bar

A macOS menu bar app for controlling mitmproxy's system proxy and web console.

## Features

- **Menu bar icon** with SF Symbols showing proxy status
- **Toggle system proxy** on/off (HTTP and HTTPS)
- **Launch mitmweb** console in Warp terminal
- **Visual indicators**:
  - Gray network slash: Both off
  - Blue network: Proxy on
  - Green network with shield: Proxy and web console on
  - Yellow network: Web console on (unusual state)

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (for building)
- [Warp Terminal](https://www.warp.dev/) (for web console)
- [mitmproxy](https://mitmproxy.org/) installed (`brew install mitmproxy`)

## Build

### Using Swift Package Manager (Recommended)

```bash
# Build the app
swift build -c release

# The binary will be at:
# .build/release/MITMMenuBar
```

### Create an App Bundle (Optional)

To create a proper `.app` bundle that can be added to your Applications folder:

```bash
# Build release
swift build -c release

# Create app bundle structure
mkdir -p MITMMenuBar.app/Contents/MacOS
mkdir -p MITMMenuBar.app/Contents/Resources

# Copy binary
cp .build/release/MITMMenuBar MITMMenuBar.app/Contents/MacOS/

# Copy Info.plist
cp Sources/MITMMenuBar/Resources/Info.plist MITMMenuBar.app/Contents/

# Move to Applications (optional)
mv MITMMenuBar.app /Applications/
```

### Using Xcode

1. Generate Xcode project:
   ```bash
   swift package generate-xcodeproj
   ```
2. Open `MITMMenuBar.xcodeproj`
3. Build and run (Cmd+R)

## Run

### From Terminal

```bash
.build/release/MITMMenuBar
```

### From App Bundle

Double-click `MITMMenuBar.app` or:

```bash
open MITMMenuBar.app
```

## Permissions

The app may request the following permissions:

1. **Accessibility Access** - Required to send keystrokes to Warp terminal
   - Go to System Settings > Privacy & Security > Accessibility
   - Add MITMMenuBar to the list

2. **Network Settings** - `networksetup` may prompt for admin password on first use

## Usage

1. Click the network icon in the menu bar
2. **Proxy Enabled** - Toggle to turn system proxy on/off
3. **Web Console** - Toggle to launch/stop mitmweb in Warp
4. **Open mitmproxy Web UI** - Opens http://127.0.0.1:8081 in browser (only active when web console is running)
5. **Quit** - Exit the app

## Keyboard Shortcuts

- `Cmd+P` - Toggle proxy
- `Cmd+W` - Toggle web console
- `Cmd+O` - Open web UI
- `Cmd+Q` - Quit

## Configuration

The default settings are:
- Proxy host: `127.0.0.1`
- Proxy port: `8080`
- Network interface: `Wi-Fi`
- mitmweb URL: `http://127.0.0.1:8081`

To modify these, edit the respective manager files:
- `Sources/MITMMenuBar/ProxyManager.swift` - proxy settings
- `Sources/MITMMenuBar/MitmwebManager.swift` - mitmweb command

## Troubleshooting

### Proxy not toggling
- Ensure you're connected to Wi-Fi
- Check System Settings > Network > Wi-Fi > Details > Proxies

### Web console not launching
- Ensure Warp is installed
- Grant Accessibility permissions to the app
- Verify mitmproxy is installed: `which mitmweb`

### Icon not updating
- The app polls status every 2 seconds
- Click the icon to force a visual update

## Auto-Start on Login

1. Open System Settings > General > Login Items
2. Click "+" under "Open at Login"
3. Select MITMMenuBar.app

## License

MIT
