# MITM Menu Bar

A macOS menu bar app for controlling mitmproxy's system proxy and web console.

Everything lives in a single menu bar popup. Settings and rules scroll while the
app status and main controls stay visible. Endpoint rows show the path, host,
method, status, and any configured delay; click a row to edit it.

## Features

- **Toggle system proxy** on/off (HTTP and HTTPS)
- **Launch mitmweb** console as a background process, on a **configurable web port**
- **One-click "Start all / Stop all"** — enables the proxy and console together
- **Response overrides** — mock any endpoint by returning custom JSON (great for React Native / API development); matching requests are short-circuited and never hit the real server. The response editor is **drag-resizable**
- **Response delays** — add a per-endpoint delay in seconds to mocked or real server responses, without holding up unrelated requests
- **CORS bypass (dev)** — inject `Access-Control-Allow-*` headers and answer preflight requests so a browser dev client can call APIs that don't allow its origin
- **Menu bar icon** whose color reflects state:
  - Gray `network.slash`: both off
  - Blue `network`: proxy on
  - Green shield: proxy + console on (working)
  - Yellow shield: console only
  - **Red warning triangle**: proxy on but console off — traffic is black-holed (no internet)

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

### Build and install the app

```bash
./build.sh
```

This builds the release app with its icon and installs it directly to
`/Applications/MITMMenuBar.app`. Future runs update that same copy; the script
stages the bundle in a temporary directory instead of leaving a second app in the
project folder. The app's saved rules and settings are retained.

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

Open **MITM Menu Bar** from Applications, or:

```bash
open /Applications/MITMMenuBar.app
```

## Permissions

**Network Settings** — `networksetup` may prompt for an admin password the first
time the proxy is toggled.

## Usage

Click the menu bar icon to open the popup:

- **Start all / Stop all** — enable the proxy and start the console in one click
- **System proxy** — toggle the system proxy. Enabling it also starts the console
  (the proxy points traffic at the console, so it must be running); stopping the
  console turns the proxy back off
- **Web Console** — start/stop mitmweb
- **Console port** — the mitmweb web UI port (default `8081`); persisted across
  launches. Changing it while running restarts the console
- **Open console** — opens `http://127.0.0.1:<port>` (enabled while running)
- **Bypass CORS** — see [CORS bypass](#cors-bypass) below
- **Response Overrides** — mock endpoints inline (see below)
- **Quit**

Standard text-editing shortcuts (`⌘C` / `⌘V` / `⌘X` / `⌘A`) work in the input fields.

## Response Overrides

Mock API responses without touching your backend — ideal when developing a
React Native app against endpoints you don't control yet.

In the **Response Overrides** section of the popup:

1. Click **Add rule** to open a new rule and fill in:
   - **Endpoint** — a substring matched against the full request URL (e.g. `/api/users`)
   - **Method** — `ANY` or a specific verb (GET, POST, …)
   - **Response delay** — extra time before returning the response; defaults to `0`
     (no delay). Decimals such as `0.5` are supported
   - **Override response** — on by default. Turn off to delay the real server's
     response without replacing its status, headers, or body
   - **Status code** — defaults to `200`; available when overriding the response
   - **Response body (JSON)** — the custom payload returned to the client. Drag the
     bottom-right grip to resize the editor
2. Make sure the **Web Console** is running.

Editing an endpoint/status field and pressing **Enter** commits it. When a request
matches an enabled rule with **Override response** on, mitmproxy short-circuits it and returns your custom JSON —
the real server is never contacted. Mocked responses include CORS headers so they
also work from a browser. Edits apply **live**; no need to restart the console.

To delay an endpoint by **5 seconds** without mocking it, add a rule with that
endpoint, set **Response delay** to `5`, and turn **Override response** off.
The real server is contacted normally, then the proxy waits 5 extra seconds before
delivering its response. Keep the toggle on to apply the same delay to a mocked response.
The first enabled matching rule wins; delays from overlapping rules are not added.
CORS preflight (`OPTIONS`) requests are not delayed. The delay also applies before
headers or body data are delivered when response streaming is enabled.
Existing saved rules retain their mocked responses with no delay.

Rules are stored in `~/.mitmmenubar/overrides.json`, loaded by an addon script
(`~/.mitmmenubar/response_override.py`) that the app writes on launch and passes
to mitmweb via `-s`.

## CORS bypass

Browsers block cross-origin responses that lack `Access-Control-Allow-Origin`.
When developing React Native **on web**, calls to an API that doesn't whitelist
your dev origin fail with a CORS error (native builds have no CORS check, so the
same call works on device).

Enable **Bypass CORS** and the addon will:

- answer preflight `OPTIONS` requests with `204` + CORS headers, and
- inject `Access-Control-Allow-Origin` (reflecting the request's `Origin`),
  `-Allow-Methods`, `-Allow-Headers`, and `-Allow-Credentials` into responses.

This requires the **system proxy on** and the **mitmproxy CA cert trusted** in the
browser (needed to decrypt HTTPS). It's a dev-only workaround — the real fix is the
backend allowing your origin.

> **HTTPS note:** For `https://` endpoints (most APIs), the client/simulator must
> trust mitmproxy's CA certificate. With the proxy on, visit
> [mitm.it](http://mitm.it) to install it. See the
> [mitmproxy certificate docs](https://docs.mitmproxy.org/stable/concepts-certificates/).

## Configuration

Configurable in the app:
- **Console (web UI) port** — default `8081`, persisted via `UserDefaults`

Hardcoded (edit the source to change):
- Proxy host `127.0.0.1`, proxy port `8080`, network interface `Wi-Fi` —
  `Sources/MITMMenuBar/ProxyManager.swift`
- mitmweb launch args (`--ignore-hosts`, addon) — `Sources/MITMMenuBar/MitmwebManager.swift`

Apple/iCloud and WhatsApp media hosts bypass TLS inspection so those apps keep
working while the proxy is enabled. Their encrypted traffic will not appear in
mitmweb and cannot be targeted by response overrides.

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

### CORS still failing
- Confirm **Bypass CORS** is on and the **Web Console** is running
- For `https://` APIs, the mitmproxy CA cert must be trusted in the browser (visit [mitm.it](http://mitm.it) with the proxy on)
- Make sure the browser's traffic actually goes through the system proxy

### "No internet" while the proxy is on
- The proxy needs the console (mitmweb) listening. The app couples them so this
  shouldn't happen; if the icon is a **red triangle**, toggle everything off

### iCloud or WhatsApp media does not load
- Restart the Web Console after updating the app so the current bypass list is
  applied. iCloud and WhatsApp media connections are passed through without TLS
  inspection because those clients reject intercepted certificates.

### Icon not updating
- Status refreshes when you open the popup — there is no background polling

## Auto-Start on Login

1. Open System Settings > General > Login Items
2. Click "+" under "Open at Login"
3. Select MITMMenuBar.app

## License

MIT
