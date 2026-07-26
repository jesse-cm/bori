import AppKit
import Foundation

enum Browser: CaseIterable {
    case chrome, safari

    var appName: String {
        switch self {
        case .chrome: return "Google Chrome"
        case .safari: return "Safari"
        }
    }

    var bundleID: String {
        switch self {
        case .chrome: return "com.google.Chrome"
        case .safari: return "com.apple.Safari"
        }
    }

    var isRunning: Bool {
        !NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty
    }

    /// AppleScript expression for the index of a window's active tab.
    var activeTabIndexExpr: String {
        switch self {
        case .chrome: return "active tab index of w"
        case .safari: return "index of current tab of w"
        }
    }

    var tabTitleProperty: String {
        switch self {
        case .chrome: return "title"
        case .safari: return "name"
        }
    }
}

struct WindowSnapshot {
    let browser: Browser
    let activeTabIndex: Int
    let tabs: [(title: String, url: String)]
}

struct SweepResult {
    let date: Date
    let windowCount: Int
    let tabCount: Int
    let shelfPath: String?
}

/// Enumerates, shelves, and closes browser windows over Apple Events.
/// The first script that runs is what triggers the one unavoidable
/// Automation permission dialog.
final class Sweeper {
    private let shelf = ShelfWriter()

    func sweep(tabCap: Int) throws -> SweepResult {
        let now = Date()
        let running = Browser.allCases.filter(\.isRunning)
        let snapshots = running.flatMap { snapshot($0) }

        var shelfPath: String?
        if !snapshots.isEmpty {
            shelfPath = try shelf.write(snapshots, date: now)
        }

        let survivor = survivingBrowser(among: running)
        for browser in running {
            if browser == survivor {
                run(closeOthersAndPruneScript(browser, cap: tabCap))
            } else {
                run("tell application \"\(browser.appName)\" to close every window")
            }
        }

        return SweepResult(
            date: now,
            windowCount: snapshots.count,
            tabCount: snapshots.reduce(0) { $0 + $1.tabs.count },
            shelfPath: shelfPath
        )
    }

    /// During a session: keep every window of every running browser at the cap.
    func enforceTabCap(_ cap: Int) {
        for browser in Browser.allCases where browser.isRunning {
            run(pruneAllWindowsScript(browser, cap: cap))
        }
    }

    /// During a session: any tab sitting on a blocked host is turned to
    /// the interlude page. /etc/hosts only stops new connections — an
    /// open tab keeps its established one — so within one poll cycle the
    /// tab becomes a quiet encouragement instead. Never a punishment.
    func redirectTabs(matching blockedHosts: [String], to destination: URL) {
        guard !blockedHosts.isEmpty else { return }
        let needles = blockedHosts.map { $0.lowercased() }
        for browser in Browser.allCases where browser.isRunning {
            var commands: [String] = []
            for (windowIndex, window) in snapshot(browser).enumerated() {
                for (index, tab) in window.tabs.enumerated() {
                    guard let host = URL(string: tab.url)?.host?.lowercased(),
                          needles.contains(where: { host == $0 || host.hasSuffix("." + $0) })
                    else { continue }
                    commands.append(
                        "\ttry\n\t\tset URL of tab \(index + 1) of window \(windowIndex + 1) " +
                        "to \"\(destination.absoluteString)\"\n\tend try")
                }
            }
            guard !commands.isEmpty else { continue }
            run("tell application \"\(browser.appName)\"\n\(commands.joined(separator: "\n"))\nend tell")
            NSLog("[bori] %d tab(s) were turned to the interlude", commands.count)
        }
    }

    // MARK: - Snapshot

    private func snapshot(_ browser: Browser) -> [WindowSnapshot] {
        let script = """
        tell application "\(browser.appName)"
        	set winData to {}
        	repeat with w in windows
        		set tabData to {}
        		repeat with t in tabs of w
        			set tTitle to ""
        			set tURL to ""
        			try
        				set tTitle to (\(browser.tabTitleProperty) of t) as text
        			end try
        			try
        				set tURL to (URL of t) as text
        			end try
        			set end of tabData to {tTitle, tURL}
        		end repeat
        		set idx to 1
        		try
        			set idx to \(browser.activeTabIndexExpr)
        		end try
        		set end of winData to {idx, tabData}
        	end repeat
        	return winData
        end tell
        """
        guard let result = run(script) else { return [] }
        var windows: [WindowSnapshot] = []
        for i in 0..<result.numberOfItems {
            guard let w = result.atIndex(i + 1) else { continue }
            let activeIndex = Int(w.atIndex(1)?.int32Value ?? 1)
            var tabs: [(String, String)] = []
            if let tabList = w.atIndex(2) {
                for j in 0..<tabList.numberOfItems {
                    guard let t = tabList.atIndex(j + 1) else { continue }
                    let title = t.atIndex(1)?.stringValue ?? ""
                    let url = t.atIndex(2)?.stringValue ?? ""
                    if title.isEmpty && url.isEmpty { continue }
                    tabs.append((title, url))
                }
            }
            if !tabs.isEmpty {
                windows.append(WindowSnapshot(browser: browser, activeTabIndex: activeIndex, tabs: tabs))
            }
        }
        return windows
    }

    // MARK: - Closing

    /// The frontmost running browser keeps its front window; ties go to
    /// the order of Browser.allCases.
    private func survivingBrowser(among running: [Browser]) -> Browser? {
        if let front = NSWorkspace.shared.frontmostApplication?.bundleIdentifier,
           let match = running.first(where: { $0.bundleID == front }) {
            return match
        }
        return running.first
    }

    private func closeOthersAndPruneScript(_ browser: Browser, cap: Int) -> String {
        let activeExpr = browser == .chrome ? "active tab index" : "index of current tab"
        return """
        tell application "\(browser.appName)"
        	repeat while (count of windows) > 1
        		close last window
        	end repeat
        	if (count of windows) is 1 then
        		tell front window
        			repeat while (count of tabs) > \(cap)
        				set n to count of tabs
        				if (\(activeExpr)) = n then
        					close tab (n - 1)
        				else
        					close tab n
        				end if
        			end repeat
        		end tell
        	end if
        end tell
        """
    }

    private func pruneAllWindowsScript(_ browser: Browser, cap: Int) -> String {
        let activeExpr = browser == .chrome ? "active tab index of w" : "index of current tab of w"
        return """
        tell application "\(browser.appName)"
        	repeat with w in windows
        		repeat while (count of tabs of w) > \(cap)
        			set n to count of tabs of w
        			if (\(activeExpr)) = n then
        				close tab (n - 1) of w
        			else
        				close tab n of w
        			end if
        		end repeat
        	end repeat
        end tell
        """
    }

    @discardableResult
    private func run(_ source: String) -> NSAppleEventDescriptor? {
        guard let script = NSAppleScript(source: source) else { return nil }
        var error: NSDictionary?
        let result = script.executeAndReturnError(&error)
        if let error {
            // Calm log only — never a dialog. -1743 means Automation
            // permission was declined in System Settings.
            NSLog("[bori] a browser declined to be tidied: %@",
                  error[NSAppleScript.errorMessage] as? String ?? "\(error)")
            return nil
        }
        return result
    }
}
