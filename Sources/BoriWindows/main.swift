#if os(Windows)
import Foundation
import WinSDK
import BoriEngine

// Bori for Windows, step one of the port: a notification-area tray app
// running the same session engine and the same ~/.bori.toml. Sessions,
// schedules, the extend-only ratchet, hosts blocking, and polite app
// blocking all work; the browser sweep and the interlude await CDP
// (see docs/windows.md). Same rules: no prompts, no early end.

let trayMessage = UINT(WM_APP) + 1
let beginCommand: UINT_PTR = 10
let extendCommand: UINT_PTR = 11
let settingsCommand: UINT_PTR = 12

final class BoriWindowsApp {
    static let shared = BoriWindowsApp()

    let engine: SessionEngine
    var config: BoriConfig
    private var configModified: Date?
    private let hosts = WindowsHosts()
    private let blocker = WindowsAppBlocker()
    private var enforceTickCount = 0

    private let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .none
        f.timeStyle = .short
        f.amSymbol = "a.m."
        f.pmSymbol = "p.m."
        return f
    }()

    private init() {
        let path = BoriConfig.defaultPath
        if !FileManager.default.fileExists(atPath: path) {
            try? BoriConfig.sampleTOML.write(toFile: path, atomically: true, encoding: .utf8)
            NSLog("[bori] a starter .bori.toml was written to %@", path)
        }
        config = (try? BoriConfig.load()) ?? BoriConfig()
        engine = SessionEngine(config: config, restoredSession: WindowsSessionStore.restore())
        if case .running = engine.state(at: Date()) {
            hosts.block(config.blockedHosts)
        }
    }

    // MARK: - Clock

    func tick() {
        reloadConfigIfChanged()
        process(events: engine.tick(at: Date()))
        if case .running = engine.state(at: Date()) {
            if enforceTickCount % 5 == 0 {
                blocker.enforce(blockedApps: config.blockedApps)
            }
            enforceTickCount += 1
        }
    }

    private func process(events: [SessionEvent]) {
        for event in events {
            switch event {
            case .sessionBegan:
                WindowsSessionStore.save(engine.session)
                hosts.block(config.blockedHosts)
                blocker.reset()
                enforceTickCount = 0
                blocker.enforce(blockedApps: config.blockedApps)
            case .sessionExtended:
                WindowsSessionStore.save(engine.session)
            case .sessionEnded:
                WindowsSessionStore.clear()
                hosts.unblock()
                blocker.reset()
            }
        }
    }

    private func reloadConfigIfChanged() {
        let path = BoriConfig.defaultPath
        let modified = (try? FileManager.default.attributesOfItem(atPath: path))?[.modificationDate] as? Date
        guard modified != configModified else { return }
        configModified = modified
        do {
            let previousHosts = config.blockedHosts
            config = try BoriConfig.load()
            engine.updateConfig(config)
            if case .running = engine.state(at: Date()), config.blockedHosts != previousHosts {
                config.blockedHosts.isEmpty ? hosts.unblock() : hosts.block(config.blockedHosts)
            }
        } catch {
            NSLog("[bori] .bori.toml could not be read (%@) — the previous settings remain", "\(error)")
        }
    }

    // MARK: - Menu

    func handle(command: UINT_PTR) {
        reloadConfigIfChanged()
        switch command {
        case beginCommand:
            process(events: engine.begin(at: Date()))
        case extendCommand:
            process(events: engine.extend(at: Date()))
        case settingsCommand:
            openSettings()
        default:
            break
        }
    }

    /// The status sentence and the text lines, exactly like the macOS panel.
    func menuLines() -> [(text: String, command: UINT_PTR?, enabled: Bool)] {
        let now = Date()
        switch engine.state(at: now) {
        case .running(_, let end):
            return [
                ("Bori is asleep — the session ends at \(time(end)).", nil, false),
                ("Add fifteen minutes — until \(time(end.addingTimeInterval(900)))", extendCommand, true),
                ("End the session — it ends on its own", nil, false),
                ("Open the settings — apps, sites, schedule", settingsCommand, true),
            ]
        case .scheduled(let nextStart, let minutes):
            return [
                ("The room is quiet — a session begins \(dayPhrase(nextStart)).", nil, false),
                ("Begin a session — \(config.sessionMinutes) minutes", beginCommand, true),
                ("The schedule — \(minutes) minutes", nil, false),
                ("Open the settings — apps, sites, schedule", settingsCommand, true),
            ]
        case .idle:
            return [
                ("The room is quiet — no session is running.", nil, false),
                ("Begin a session — \(config.sessionMinutes) minutes", beginCommand, true),
                ("Open the settings — apps, sites, schedule", settingsCommand, true),
            ]
        }
    }

    private func openSettings() {
        let root = ProcessInfo.processInfo.environment["SystemRoot"] ?? "C:\\Windows"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "\(root)\\System32\\notepad.exe")
        process.arguments = [BoriConfig.defaultPath]
        try? process.run()
    }

    private func time(_ date: Date) -> String {
        timeFormatter.string(from: date)
    }

    private func dayPhrase(_ date: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return "at \(time(date))" }
        if calendar.isDateInTomorrow(date) { return "tomorrow at \(time(date))" }
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return "on \(formatter.string(from: date)) at \(time(date))"
    }
}

// MARK: - Win32 plumbing

func showTrayMenu(_ window: HWND?) {
    guard let menu = CreatePopupMenu() else { return }
    defer { DestroyMenu(menu) }

    for line in BoriWindowsApp.shared.menuLines() {
        var flags = UINT(MF_STRING)
        if !line.enabled { flags |= UINT(MF_GRAYED) }
        let wide = Array(line.text.utf16) + [0]
        wide.withUnsafeBufferPointer {
            _ = AppendMenuW(menu, flags, line.command ?? 0, $0.baseAddress)
        }
    }

    var point = POINT()
    _ = GetCursorPos(&point)
    _ = SetForegroundWindow(window)
    // Selection arrives as WM_COMMAND (TPM_RETURNCMD's return value is
    // unusable from Swift — the BOOL import swallows the command id).
    _ = TrackPopupMenu(
        menu,
        UINT(TPM_RIGHTBUTTON),
        point.x, point.y, 0, window, nil
    )
}

func boriWndProc(_ window: HWND?, _ message: UINT, _ wParam: WPARAM, _ lParam: LPARAM) -> LRESULT {
    switch message {
    case trayMessage:
        let event = UINT(lParam & 0xFFFF)
        if event == UINT(WM_LBUTTONUP) || event == UINT(WM_RBUTTONUP) {
            showTrayMenu(window)
        }
        return 0
    case UINT(WM_COMMAND):
        BoriWindowsApp.shared.handle(command: UINT_PTR(wParam & 0xFFFF))
        return 0
    case UINT(WM_TIMER):
        BoriWindowsApp.shared.tick()
        return 0
    case UINT(WM_DESTROY):
        PostQuitMessage(0)
        return 0
    default:
        return DefWindowProcW(window, message, wParam, lParam)
    }
}

// Hide the console the SwiftPM executable brings along.
if let console = GetConsoleWindow() {
    _ = ShowWindow(console, SW_HIDE)
}

let className = Array("BoriTray".utf16) + [0]
let window: HWND? = className.withUnsafeBufferPointer { name in
    var windowClass = WNDCLASSW()
    windowClass.lpfnWndProc = { hwnd, msg, wp, lp in boriWndProc(hwnd, msg, wp, lp) }
    windowClass.hInstance = GetModuleHandleW(nil)
    windowClass.lpszClassName = name.baseAddress
    guard RegisterClassW(&windowClass) != 0 else { return nil }
    return CreateWindowExW(
        0, name.baseAddress, name.baseAddress, 0,
        0, 0, 0, 0,
        HWND(bitPattern: -3), // message-only window
        nil, GetModuleHandleW(nil), nil
    )
}

guard let window else {
    NSLog("[bori] the tray window could not be made")
    exit(1)
}

var iconData = NOTIFYICONDATAW()
iconData.cbSize = DWORD(MemoryLayout<NOTIFYICONDATAW>.size)
iconData.hWnd = window
iconData.uID = 1
iconData.uFlags = UINT(NIF_MESSAGE) | UINT(NIF_ICON) | UINT(NIF_TIP)
iconData.uCallbackMessage = trayMessage
iconData.hIcon = LoadIconW(nil, UnsafePointer<WCHAR>(bitPattern: 32512)) // IDI_APPLICATION
let tip = Array("Bori".utf16) + [0]
withUnsafeMutableBytes(of: &iconData.szTip) { destination in
    tip.withUnsafeBytes { source in
        destination.copyBytes(from: source.prefix(destination.count))
    }
}
_ = Shell_NotifyIconW(DWORD(NIM_ADD), &iconData)

_ = SetTimer(window, 1, 1000, nil)
BoriWindowsApp.shared.tick()

var message = MSG()
while GetMessageW(&message, nil, 0, 0) {
    _ = TranslateMessage(&message)
    _ = DispatchMessageW(&message)
}

_ = Shell_NotifyIconW(DWORD(NIM_DELETE), &iconData)
#else
print("This executable is the Windows tray app; on this platform, use the Bori app instead.")
#endif
