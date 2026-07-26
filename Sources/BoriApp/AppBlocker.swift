#if os(macOS)
import AppKit

/// Polite enforcement of the app blocklist: blocked apps are asked to
/// terminate; any still running a few seconds later are hidden.
/// Nothing is ever force-killed.
final class AppBlocker {
    private var askedAt: [pid_t: Date] = [:]

    func reset() {
        askedAt = [:]
    }

    func enforce(blockedApps: [String]) {
        guard !blockedApps.isEmpty else { return }
        let needles = Set(blockedApps.map { $0.lowercased() })
        for app in NSWorkspace.shared.runningApplications {
            guard app.activationPolicy == .regular,
                  app.processIdentifier != ProcessInfo.processInfo.processIdentifier,
                  app.bundleIdentifier != "com.apple.finder" else { continue }
            let name = app.localizedName?.lowercased() ?? ""
            let bundleID = app.bundleIdentifier?.lowercased() ?? ""
            guard needles.contains(name) || needles.contains(bundleID) else { continue }

            if let asked = askedAt[app.processIdentifier] {
                if Date().timeIntervalSince(asked) > 4, !app.isTerminated, !app.isHidden {
                    NSLog("[bori] %@ preferred to stay, so it was put out of sight", app.localizedName ?? "an app")
                    app.hide()
                }
            } else {
                askedAt[app.processIdentifier] = Date()
                NSLog("[bori] %@ was asked to close for the session", app.localizedName ?? "an app")
                app.terminate()
            }
        }
    }
}
#endif
