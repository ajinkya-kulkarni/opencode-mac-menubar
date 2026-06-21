# OpenCode Go Lite

A tiny native macOS menu bar app for OpenCode Go usage.

It shows all three OpenCode Go quota windows directly in the menu bar:

```text
R0 W2 M1
5h 9h 21d
```

If a window reaches 100% or more, the menu bar replaces that percentage with `!`:

```text
R! W2 M1
12m 9h 21d
```

No Electron, no Node, no Python, no webview. It is Swift + AppKit + `NSStatusItem`.

## Display rules

Top row:

```text
R<rolling> W<weekly> M<monthly>
```

Bottom row:

```text
<rolling reset> <weekly reset> <monthly reset>
```

Usage formatting:

- `0` to `99` means usage percentage.
- `!` means that window is at `>=100%`.
- No threshold states/colors.

Reset formatting:

- under 60 minutes: nearest minute, for example `12m`
- under 48 hours: nearest hour, for example `5h`
- 48 hours or more: nearest day, for example `21d`

## Build

```bash
cd opencode-go-lite
./make_app.sh
open .build/OpenCodeGoLite.app
```

You need macOS with Xcode Command Line Tools:

```bash
xcode-select --install
```

The app is menu-bar-only and has no Dock icon.

## Data source option 1: local JSON, safest MVP

Create this file:

```bash
mkdir -p ~/.config/opencode-go-lite
cp sample-usage.json ~/.config/opencode-go-lite/usage.json
```

Or create it manually:

```json
{
  "rolling": {"percent": 0, "resetsIn": "4h 49m"},
  "weekly": {"percent": 2, "resetsIn": "8h 51m"},
  "monthly": {"percent": 1, "resetsIn": "21d 5h"}
}
```

The menu bar will show roughly:

```text
R0 W2 M1
5h 9h 21d
```

because reset times are rounded compactly.

## Data source option 2: dashboard cURL

This is experimental because OpenCode Go's live dashboard usage is not a stable public API.

1. Open the OpenCode Go dashboard in your browser.
2. Open DevTools → Network.
3. Refresh the dashboard.
4. Find the request that returns the rolling/weekly/monthly usage JSON.
5. Right click it → Copy → Copy as cURL.
6. Save it here:

```bash
mkdir -p ~/.config/opencode-go-lite
nano ~/.config/opencode-go-lite/request.curl
chmod 600 ~/.config/opencode-go-lite/request.curl
```

The app reads `request.curl`, fetches the JSON with `URLSession`, and recursively tries to find rolling, weekly, and monthly usage fields.

Important: the cURL can contain your auth cookie. Keep it private. Do not commit it.

If dashboard fetching fails, the app falls back to `usage.json`, then to the last-good cache.

## Menu

Click the menu bar item to see:

- Rolling percentage + reset
- Weekly percentage + reset
- Monthly percentage + reset
- Source and last update
- Refresh Now
- Open OpenCode Dashboard
- Open Config Folder
- Create Sample usage.json
- Quit

## Files

```text
~/.config/opencode-go-lite/usage.json       # optional local data
~/.config/opencode-go-lite/request.curl     # optional dashboard request, private
~/.config/opencode-go-lite/last-good.json   # cache
```

## Notes

This app intentionally does not copy OpenCode Bar. It is a minimal personal widget focused only on OpenCode Go and only the three windows: rolling, weekly, monthly.
