# MITM Menu Bar

A macOS menu bar app for controlling mitmproxy's system proxy and web console.

## Features

- **Menu bar icon** with SF Symbols showing proxy status
- **Toggle system proxy** on/off (HTTP and HTTPS)
- **Launch mitmweb** console as a background process
- **Response overrides** — mock any endpoint by returning custom JSON (great for React Native / API development); matching requests are short-circuited and never hit the real server
- **Visual indicators**:
  - Gray network slash: Both off
  - Blue network: Proxy on
  - Green network with shield: Proxy and web console on
  - Yellow network: Web console on (unusual state)

## Requirements

- macOS 13.0 or later
- Xcode Command Line Tools (for building)
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
3. **Web Console** - Toggle to launch/stop mitmweb
4. **Open mitmproxy Web UI** - Opens http://127.0.0.1:8081 in browser (only active when web console is running)
5. **Response Overrides…** - Open the editor to mock endpoints (see below)
6. **Quit** - Exit the app

## Response Overrides

Mock API responses without touching your backend — ideal when developing a
React Native app against endpoints you don't control yet.

1. Open **Response Overrides…** (`Cmd+R`) from the menu.
2. Click **+** to add a rule and fill in:
   - **Endpoint** — a substring matched against the full request URL (e.g. `/api/users`)
   - **Method** — `ANY` or a specific verb (GET, POST, …)
   - **Status code** — defaults to `200`
   - **Response body (JSON)** — the custom payload returned to the client
3. Make sure **Web Console** is running.

When a request matches an enabled rule, mitmproxy short-circuits it and returns
your custom JSON — the real server is never contacted. Edits apply **live**; you
don't need to restart the web console.

Rules are stored in `~/.mitmmenubar/overrides.json`, loaded by an addon script
(`~/.mitmmenubar/response_override.py`) that the app writes on launch and passes
to mitmweb via `-s`.

> **HTTPS note:** For `https://` endpoints (most APIs), the client/simulator must
> trust mitmproxy's CA certificate. See the [mitmproxy certificate docs](https://docs.mitmproxy.org/stable/concepts-certificates/).

## Keyboard Shortcuts

- `Cmd+P` - Toggle proxy
- `Cmd+W` - Toggle web console
- `Cmd+O` - Open web UI
- `Cmd+R` - Open Response Overrides
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
- Verify mitmproxy is installed: `which mitmweb`

### Overrides not applying
- Make sure the **Web Console** is running (overrides only work while mitmweb runs)
- Check that the endpoint substring actually appears in the request URL
- Confirm the rule is enabled and its JSON body is valid

### Icon not updating
- Status refreshes when you open the menu — click the icon to force a refresh

## Auto-Start on Login

1. Open System Settings > General > Login Items
2. Click "+" under "Open at Login"
3. Select MITMMenuBar.app

## License

MIT
