# Bori

Bori is a small menu bar companion that puts the loud parts of your
computer away for a while. When a session begins, your browser windows are
shelved into a dated bookmarks file, distracting apps are politely asked to
leave, and distracting sites stop resolving — and any tab that wanders back
to one is quietly turned into a page with an encouraging quote instead.
When the session ends, everything is released. Nothing is restored for you;
the shelf simply keeps what you had, in case you want it back.

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
   turned to the interlude — a motivational quote picked at random and a note of when the
   session ends.

Sessions begin from the menu bar dropdown or on a schedule. The dropdown
is a single quiet panel: the dot-matrix Bori (asleep during a session,
sitting otherwise), a status sentence, and a few text lines. That's the
whole interface.

## Building

No dependencies on either platform. `swift test` runs the engine and
hosts-file test suites everywhere.

### macOS

Requires macOS 13+ and Xcode's Swift toolchain.

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

### Windows

Requires the Swift toolchain for Windows —
[swift.org/install](https://www.swift.org/install/windows/), or
`winget install --id Swift.Toolchain`. Then, from the repo:

```powershell
swift build -c release
.\.build\release\BoriWindows.exe
```

The tray icon appears in the notification area; the menu holds the same
text lines, and the config lives at `%USERPROFILE%\.bori.toml` (a
starter file is written on first run). Two things to know:

- **Site blocking needs elevation** — run `BoriWindows.exe` as
  administrator, since it edits
  `%SystemRoot%\System32\drivers\etc\hosts` directly for now. Without
  it, sessions still run and apps are still put away; sites are not.
- **The browser sweep, tab cap, and interlude are not on Windows yet**
  (`docs/windows.md` has the plan). The Windows build compiles and
  tests in CI on every push, but it is young — expect edges.

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

## License

MIT.
