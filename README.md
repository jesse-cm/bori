# Bori

Bori is a small macOS menu bar companion that puts the loud parts of your
computer away for a while. When a session begins, your browser windows are
shelved into a dated bookmarks file, distracting apps are politely asked to
leave, and distracting sites stop resolving — and any tab that wanders back
to one is quietly turned into a page with an encouraging quote instead.
When the session ends, everything is released. Nothing is restored for you;
the shelf simply keeps what you had, in case you want it back.

Bori is opinionated about how focus tools should behave:

- **No prompts, ever.** There are no confirmation dialogs, no "are you
  sure", no settings windows. All decisions live in one config file;
  the app only executes and displays.
- **Sessions cannot be ended early from the UI.** The only override is
  editing the config file. "Add fifteen minutes" is the only button-shaped
  thing Bori has, and it only moves the end further away.
- **Nothing is punished.** Apps that refuse to quit are hidden, never
  force-killed. Blocked tabs aren't slammed shut — they're turned to an
  interlude page with words from Maya Angelou, Octavia Butler, Grace
  Hopper, Mary Oliver, and friends.
- **Nothing is restored automatically.** Snapshots go to the shelf as
  plain, importable bookmarks files. What returns is up to you.

## What a session does

1. **The sweep.** Every Chrome and Safari window and tab is written to
   `~/Bori/shelf/<date>.html` (Netscape bookmarks format, one folder per
   window — importable into any browser, or readable as-is). All windows
   close except the frontmost, which is pruned to the tab cap.
2. **Apps.** Blocklisted apps are asked to terminate; any that decline are
   hidden. Ones launched mid-session get the same treatment within a poll
   cycle, silently.
3. **Sites.** A privileged helper writes the blocklisted hosts into
   `/etc/hosts` (marked block, `www.` variants included) and flushes the
   DNS cache. The block clears when the session ends — and the helper
   carries its own deadline, so the block lapses even if the app dies.
4. **Wandering tabs.** Once a second, any tab sitting on a blocked host is
   turned to the interlude — a quote picked at random, and a note of when
   the session ends.

Sessions begin from the menu bar dropdown or on a schedule. The dropdown
is a single quiet panel: the dot-matrix Bori (asleep during a session,
sitting otherwise), a status sentence, and a few text lines. That's the
whole interface.

## Building

Requires macOS 13+ and Xcode's Swift toolchain. No dependencies.

```sh
scripts/make-app.sh
open dist/Bori.app
```

macOS will ask for two permissions, once each:

- **Automation** (Apple Events for Chrome/Safari) — raised by the first
  sweep. This is the one unavoidable dialog.
- **Login Items approval** for the hosts helper — flip the toggle under
  System Settings → General → Login Items & Extensions → Allow in the
  Background. Until then, site blocking is logged but not enforced, and
  the panel shows a line that takes you there.

`swift test` runs the engine and hosts-file test suites.

## Configuration

Everything lives in `~/.bori.toml` (a starter file is written on first
launch, and the panel has a line that opens it). Edits are picked up
within a second — including mid-session, which is the sanctioned way to
change a running session's host list.

```toml
# Minutes a manually begun session lasts.
session_minutes = 50

# Each browser window is kept to this many tabs during a session.
tab_cap = 10

[blocklist]
# App names or bundle identifiers.
apps = ["Slack", "Discord"]

# Hosts put away for the length of a session.
hosts = ["twitter.com", "x.com", "instagram.com"]

# Sessions can also begin on a schedule. Repeat this block freely.
[[schedule]]
days = ["mon", "tue", "wed", "thu", "fri"]
start = "09:00"
minutes = 90
```

## Architecture

- `Sources/BoriEngine` — the session engine: a pure state machine
  (idle / scheduled / running) with no UI imports and no clock of its
  own. Ending a session early isn't an unexposed feature; the API for it
  does not exist. Includes a small dependency-free TOML reader.
- `Sources/BoriApp` — the AppKit shell: status item, WKWebView panel
  rendering `theme.css` + `bori-screen.js` (the canonical design files),
  the sweep and tab enforcement over Apple Events, and the app blocklist
  via NSWorkspace.
- `Sources/BoriHelper` — the privileged daemon (SMAppService + XPC).
  It edits one marked block in `/etc/hosts`, flushes DNS, and nothing
  else. Hostnames are strictly validated before they can touch the file.
- The Windows port, when it comes, swaps the enforcement layer — the
  engine stays.

## Known edges

- Browsers with "Secure DNS" (DoH) pointed at a custom resolver bypass
  `/etc/hosts`; the interlude redirect still catches their tabs within a
  second. Surfacing DoH detection in the panel is on the roadmap.
- A freshly blocked site can flash for under a second if the browser
  serves it from its own cache, before the tab is turned to the
  interlude.
- The ad-hoc signature is fine for a machine you built it on;
  distributing the helper properly needs a Developer ID.
- Fraunces is the intended face; until it's bundled, the theme falls
  back to Georgia.

## License

MIT.
