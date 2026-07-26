#if os(Windows)
import Foundation
import WinSDK

/// Polite app blocking, Windows edition: blocked apps' top-level windows
/// are sent WM_CLOSE; anything still visible a few seconds later is
/// hidden. Processes are never terminated.
final class WindowsAppBlocker {
    private var askedAt: [DWORD: Date] = [:]

    func reset() {
        askedAt = [:]
    }

    private final class WindowList {
        var entries: [(window: HWND, pid: DWORD)] = []
    }

    func enforce(blockedApps: [String]) {
        guard !blockedApps.isEmpty else { return }
        let needles = Set(blockedApps.map { $0.lowercased() })

        let list = WindowList()
        let callback: WNDENUMPROC = { window, lParam in
            guard let window, IsWindowVisible(window) else { return true }
            var pid: DWORD = 0
            _ = GetWindowThreadProcessId(window, &pid)
            guard pid != 0, let raw = UnsafeRawPointer(bitPattern: Int(lParam)) else { return true }
            let list = Unmanaged<WindowList>.fromOpaque(raw).takeUnretainedValue()
            list.entries.append((window, pid))
            return true
        }
        let context = Unmanaged.passUnretained(list).toOpaque()
        _ = EnumWindows(callback, LPARAM(Int(bitPattern: context)))

        let ownPid = DWORD(ProcessInfo.processInfo.processIdentifier)
        for (window, pid) in list.entries {
            guard pid != ownPid, let name = executableName(of: pid) else { continue }
            let bare = name.hasSuffix(".exe") ? String(name.dropLast(4)) : name
            guard needles.contains(name) || needles.contains(bare) else { continue }

            if let asked = askedAt[pid] {
                if Date().timeIntervalSince(asked) > 4 {
                    NSLog("[bori] %@ preferred to stay, so it was put out of sight", bare)
                    _ = ShowWindow(window, SW_HIDE)
                }
            } else {
                askedAt[pid] = Date()
                NSLog("[bori] %@ was asked to close for the session", bare)
                _ = PostMessageW(window, UINT(WM_CLOSE), 0, 0)
            }
        }
    }

    private func executableName(of pid: DWORD) -> String? {
        guard let handle = OpenProcess(DWORD(PROCESS_QUERY_LIMITED_INFORMATION), false, pid) else {
            return nil
        }
        defer { _ = CloseHandle(handle) }
        var buffer = [WCHAR](repeating: 0, count: 260)
        var size = DWORD(buffer.count)
        guard QueryFullProcessImageNameW(handle, 0, &buffer, &size) else { return nil }
        let path = String(decodingCString: buffer, as: UTF16.self)
        return path.split(separator: "\\").last.map { $0.lowercased() }
    }
}
#endif
