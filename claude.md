# Bori — CLAUDE.md

Focus app: starting a session closes all apps and browser tabs, saving them
to a bookmarks folder called "the shelf." macOS first, Windows planned.
MIT licensed. Chrome extension (MV3) + native menu bar app, sharing one
config file.

## Behavioral rules (non-negotiable)
- ZERO runtime prompts or confirmation dialogs. All decisions live in
  config; runtime only executes and displays. Never add an "are you sure".
- Sessions cannot be ended early from the UI. Override = editing the
  config file only. "Add fifteen minutes" is allowed (extend-only ratchet).
- Sweep on session start: snapshot all windows/tabs to a dated bookmarks
  folder, close them; keep the frontmost window pruned to 10 tabs (LRU).
- Never restore snapshots automatically at session end.
- App side: polite terminate; apps that refuse get hidden, never force-killed.
- No default whitelist. Sessions trigger manually AND on schedule.

## Design (theme.css + bori-screen.js are canonical)
- Sharp corners everywhere: border-radius 0. No shadows, gradients, icons,
  emoji, buttons, or pills. Menu items are text lines with 0.5px hairlines.
- Fraunces (bundled, OFL). Status is a prose sentence; the amber em-dash
  is the only accent.
- The Bori screen is ALWAYS dark in both modes; Bori renders via
  bori-screen.js (dot-matrix). sleep = session running, sit = idle.
- Copy voice: calm, bookish, past tense, no exclamation marks. Things are
  "shelved" and "put away" — never "blocked", "killed", or "error".
- uploads/ from the design export is reference-only: never commit it
  (contains third-party GIFs).

## Architecture
One native macOS menu bar app (Swift/AppKit), no browser extension.
- Websites: /etc/hosts entries during sessions, via a privileged helper
  (SMAppService). Flush DNS cache on every change. Detect browser DoH
  ("Secure DNS") and surface it in Settings — never as a runtime prompt.
- Apps: NSWorkspace launch/termination observation. Polite terminate;
  hide what refuses. Blocked apps that launch mid-session are terminated
  within one poll cycle, silently.
- Tabs: AppleScript (Chrome + Safari) for sweep and tab-count cap.
  Poll ~5s during sessions; evict oldest tab when over cap.
- The shelf: dated standalone HTML bookmarks files in ~/Bori/shelf/,
  one per snapshot. Never auto-restored.
- Session engine is a pure state machine module, UI-independent —
  the Windows port later swaps the enforcement layer, not the logic.
- Windows (later): hosts file + Win32 process watching, same engine.