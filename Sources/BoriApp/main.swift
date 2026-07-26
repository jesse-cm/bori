#if os(macOS)
import AppKit

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
#else
// The Windows shell (tray UI, hosts service, tab enforcement) is not
// written yet — the session engine already builds and tests everywhere.
print("Bori's app layer is macOS-only for now.")
#endif
