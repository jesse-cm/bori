#if os(macOS)
import AppKit
import BoriEngine

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var engine: SessionEngine!
    private var config = BoriConfig()
    private var configModified: Date?

    private var statusItem: NSStatusItem!
    private var panelController: PanelController!

    private let sweeper = Sweeper()
    private let blocker = AppBlocker()
    private let hosts = HostsService()

    private var tickTimer: Timer?
    private var enforceTimer: Timer?
    private var enforceTickCount = 0
    private var lastSweep: SweepResult?

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.amSymbol = "a.m."
        f.pmSymbol = "p.m."
        return f
    }()

    func applicationDidFinishLaunching(_ notification: Notification) {
        writeSampleConfigIfMissing()
        reloadConfigIfChanged()
        engine = SessionEngine(config: config, restoredSession: SessionStore.restore())

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = "Bori"
        statusItem.button?.target = self
        statusItem.button?.action = #selector(togglePanel)

        panelController = PanelController { [weak self] action in
            self?.handle(action: action)
        }

        hosts.registerIfNeeded()

        // A restored session was already swept at its true beginning;
        // just pick the enforcement back up.
        if case .running = engine.state(at: Date()) {
            startEnforcement(sweep: false)
        } else {
            // No session — clear any block a crash may have left behind.
            hosts.unblock()
        }

        tickTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.tick()
        }
        tick()
    }

    // MARK: - Clock

    private func tick() {
        reloadConfigIfChanged()
        process(events: engine.tick(at: Date()))
        refreshUI()
    }

    private func process(events: [SessionEvent]) {
        for event in events {
            switch event {
            case .sessionBegan:
                SessionStore.save(engine.session)
                startEnforcement(sweep: true)
            case .sessionExtended:
                SessionStore.save(engine.session)
                // Refresh the helper's self-clear deadline and the
                // interlude's closing line.
                hosts.block(config.blockedHosts, until: engine.session?.end)
                if let end = engine.session?.end {
                    Interlude.write(endsText: time(end))
                }
            case .sessionEnded:
                SessionStore.clear()
                stopEnforcement()
            }
        }
        if !events.isEmpty { refreshUI() }
    }

    // MARK: - Actions from the panel

    private func handle(action: String) {
        reloadConfigIfChanged()
        switch action {
        case "begin":
            process(events: engine.begin(at: Date()))
        case "extend":
            process(events: engine.extend(at: Date()))
        case "settings":
            panelController.hide()
            openSettings()
        case "loginitems":
            panelController.hide()
            hosts.openLoginItems()
        default:
            break
        }
        refreshUI()
    }

    @objc private func togglePanel() {
        reloadConfigIfChanged()
        guard let button = statusItem.button else { return }
        panelController.toggle(below: button, html: PanelHTML.page(panelModel()))
    }

    // MARK: - Enforcement

    private func startEnforcement(sweep: Bool) {
        if sweep {
            // The first sweep is what raises the one unavoidable system
            // dialog: Automation permission for Chrome and Safari.
            do {
                lastSweep = try sweeper.sweep(tabCap: config.tabCap)
            } catch {
                NSLog("[bori] the shelf could not be written: %@", "\(error)")
            }
        }
        hosts.block(config.blockedHosts, until: engine.session?.end)
        if let end = engine.session?.end {
            Interlude.write(endsText: time(end))
        }
        blocker.reset()
        enforceTimer?.invalidate()
        enforceTickCount = 0
        // Tabs on shelved sites are put away within a second — before a
        // page can meaningfully render; the gentler app and tab-cap
        // checks keep their five-second rhythm.
        enforceTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            self?.enforce()
        }
        enforce()
    }

    private func stopEnforcement() {
        enforceTimer?.invalidate()
        enforceTimer = nil
        hosts.unblock()
        blocker.reset()
        // Nothing is restored: the shelf stays shelved, apps stay closed.
    }

    private func enforce() {
        sweeper.redirectTabs(matching: config.blockedHosts, to: Interlude.fileURL)
        if enforceTickCount % 5 == 0 {
            blocker.enforce(blockedApps: config.blockedApps)
            sweeper.enforceTabCap(config.tabCap)
        }
        enforceTickCount += 1
    }

    // MARK: - Config

    /// Opens ~/.bori.toml in the default editor — the file stays the only
    /// interface; this line just walks you to it.
    private func openSettings() {
        writeSampleConfigIfMissing()
        let url = URL(fileURLWithPath: BoriConfig.defaultPath)
        if !NSWorkspace.shared.open(url) {
            // No editor claims .toml — fall back to TextEdit.
            if let textEdit = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.TextEdit") {
                NSWorkspace.shared.open([url], withApplicationAt: textEdit,
                                        configuration: NSWorkspace.OpenConfiguration())
            }
        }
    }

    private func writeSampleConfigIfMissing() {
        let path = BoriConfig.defaultPath
        guard !FileManager.default.fileExists(atPath: path) else { return }
        try? BoriConfig.sampleTOML.write(toFile: path, atomically: true, encoding: .utf8)
        NSLog("[bori] a starter ~/.bori.toml was written")
    }

    private func reloadConfigIfChanged() {
        let path = BoriConfig.defaultPath
        let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        guard modified != configModified else { return }
        configModified = modified
        do {
            let previousHosts = config.blockedHosts
            config = try BoriConfig.load()
            engine?.updateConfig(config)
            // Editing the config is the sanctioned mid-session override;
            // apply a changed host list right away.
            if let engine, case .running = engine.state(at: Date()), config.blockedHosts != previousHosts {
                if config.blockedHosts.isEmpty {
                    hosts.unblock()
                } else {
                    hosts.block(config.blockedHosts, until: engine.session?.end)
                }
            }
        } catch {
            NSLog("[bori] ~/.bori.toml could not be read (%@) — the previous settings remain", "\(error)")
        }
    }

    // MARK: - Presentation

    private func refreshUI() {
        let state = engine.state(at: Date())
        updateStatusTitle(running: isRunning(state))
        if panelController.isVisible {
            panelController.render(html: PanelHTML.page(panelModel()))
        }
    }

    private func isRunning(_ state: SessionState) -> Bool {
        if case .running = state { return true }
        return false
    }

    private func updateStatusTitle(running: Bool) {
        guard let button = statusItem.button else { return }
        if running {
            let title = NSMutableAttributedString(string: "Bori ")
            title.append(NSAttributedString(
                string: "—",
                attributes: [.foregroundColor: NSColor(red: 0.79, green: 0.58, blue: 0.27, alpha: 1)]
            ))
            button.attributedTitle = title
        } else {
            button.attributedTitle = NSAttributedString(string: "Bori")
        }
    }

    private func panelModel() -> PanelModel {
        let now = Date()
        let dark = NSApp.effectiveAppearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
        let mode = dark ? "dark" : "light"

        switch engine.state(at: now) {
        case .running(_, let end):
            let detail: String
            if let sweep = lastSweep, sweep.tabCount > 0 {
                let tabs = sweep.tabCount == 1 ? "One tab was" : "\(sweep.tabCount) tabs were"
                detail = "\(tabs) shelved at \(time(sweep.date))."
            } else {
                detail = "There was nothing to shelve."
            }
            return PanelModel(
                mode: mode, pose: .sleep,
                statusHTML: "Bori is asleep<span class=\"dash\"> —</span> the session ends at \(time(end)).",
                detailHTML: detail,
                menu: [
                    MenuLine(
                        html: "Add fifteen minutes <span class=\"dash\">—</span> until \(time(end.addingTimeInterval(900)))",
                        action: "extend"
                    ),
                    MenuLine(
                        html: "End the session <span class=\"note\">— it ends on its own</span>",
                        unavailable: true
                    ),
                    helperLine,
                    settingsLine,
                ].compactMap { $0 }
            )

        case .scheduled(let nextStart, let minutes):
            return PanelModel(
                mode: mode, pose: .sit,
                statusHTML: "The room is quiet<span class=\"dash\"> —</span> a session begins \(dayPhrase(nextStart)).",
                detailHTML: shelfSummary(),
                menu: [
                    MenuLine(
                        html: "Begin a session <span class=\"dash\">—</span> \(config.sessionMinutes) minutes",
                        action: "begin"
                    ),
                    MenuLine(
                        html: "The schedule <span class=\"note\">— \(minutes) minutes</span>",
                        unavailable: true
                    ),
                    helperLine,
                    settingsLine,
                ].compactMap { $0 }
            )

        case .idle:
            return PanelModel(
                mode: mode, pose: .sit,
                statusHTML: "The room is quiet<span class=\"dash\"> —</span> no session is running.",
                detailHTML: shelfSummary(),
                menu: [
                    MenuLine(
                        html: "Begin a session <span class=\"dash\">—</span> \(config.sessionMinutes) minutes",
                        action: "begin"
                    ),
                    helperLine,
                    settingsLine,
                ].compactMap { $0 }
            )
        }
    }

    private var settingsLine: MenuLine {
        MenuLine(
            html: "Open the settings <span class=\"dash\">—</span> apps, sites, schedule",
            action: "settings"
        )
    }

    /// Shown only while sites are configured but the helper still waits
    /// for its one-time approval — a text line, never a prompt.
    private var helperLine: MenuLine? {
        guard !config.blockedHosts.isEmpty, !hosts.isReady else { return nil }
        return MenuLine(
            html: "Approve site blocking <span class=\"dash\">—</span> open Login Items",
            action: "loginitems"
        )
    }

    private func shelfSummary() -> String {
        switch ShelfWriter.snapshotCount() {
        case 0: return "Nothing has been shelved yet."
        case 1: return "The shelf holds one snapshot."
        case let n: return "The shelf holds \(n) snapshots."
        }
    }

    private func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private func dayPhrase(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) {
            return "at \(time(date))"
        }
        if calendar.isDateInTomorrow(date) {
            return "tomorrow at \(time(date))"
        }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "on \(formatter.string(from: date)) at \(time(date))"
    }
}
#endif
