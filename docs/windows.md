# The Windows port

The session engine (`BoriEngine`) and the hosts-file editing logic
(`BoriHelperCore.HostsFile`) are pure Foundation and already build and
pass their tests on Windows — CI proves this on every push. What remains
is the enforcement and display layer, which was always designed to be
swapped per platform.

## What maps to what

| macOS layer | Windows equivalent |
| --- | --- |
| Menu bar `NSStatusItem` + WKWebView panel | Notification-area tray icon + WebView2 flyout (same `theme.css` / `bori-screen.js`) |
| `/etc/hosts` via SMAppService root daemon | `%SystemRoot%\System32\drivers\etc\hosts` via a small elevated Windows service (same `HostsFile` transform, same `# bori:begin/end` markers), then `ipconfig /flushdns` |
| `NSWorkspace` app observation, polite `terminate()` then `hide()` | Win32 process watching (`EnumProcesses`/WMI events), `WM_CLOSE` to top-level windows (polite), then `ShowWindow(SW_HIDE)`/minimize for refusals — never `TerminateProcess` |
| AppleScript tab sweep and eviction (Chrome/Safari) | Chrome DevTools Protocol (launch flag `--remote-debugging-port`) or UI Automation; Edge supports CDP too. No scripting bridge exists otherwise — this is the hardest piece, and may justify reviving the MV3 extension on Windows only |
| `~/Bori/shelf/*.html` | `%USERPROFILE%\Bori\shelf\*.html` — `ShelfWriter` is portable once its `WindowSnapshot` input is |
| `~/.bori.toml` | `%USERPROFILE%\.bori.toml` — already portable |

## Ground rules carry over unchanged

Zero prompts, no early end from the UI, extend-only ratchet, nothing
force-killed, nothing auto-restored, the interlude instead of a wall.

## Sequencing

1. Tray shell with the panel rendered in WebView2, wired to the engine
   (sessions, schedules, status sentences) — no enforcement yet.
2. Hosts service + DNS flush (reuse `HostsFile`, `interlude` redirect
   needs step 3).
3. Process watching and polite app blocking.
4. Tab sweep/eviction via CDP, with the shelf writer.

Swift on Windows can build all of this in principle (the engine already
does); the shell may alternatively be a thin C#/WinUI host over the same
config file and state file formats, since the engine's contract is just
TOML in, JSON state out.
