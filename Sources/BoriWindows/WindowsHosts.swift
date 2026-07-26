#if os(Windows)
import Foundation
import BoriHelperCore

/// Windows hosts blocking: same marker block, same validation, applied
/// to %SystemRoot%\System32\drivers\etc\hosts. Writing there requires
/// the app to run elevated; when it isn't, Bori logs calmly and moves
/// on — a dedicated elevated service is the roadmap's proper answer.
final class WindowsHosts {
    private var hostsPath: String {
        let root = ProcessInfo.processInfo.environment["SystemRoot"] ?? "C:\\Windows"
        return "\(root)\\System32\\drivers\\etc\\hosts"
    }

    func block(_ hosts: [String]) {
        guard !hosts.isEmpty else { return }
        rewrite("\(hosts.count) sites were put away") { HostsFile.applying(hosts, to: $0) }
    }

    func unblock() {
        rewrite("the sites were returned") { HostsFile.removingBlock(from: $0) }
    }

    private func rewrite(_ success: String, _ transform: (String) -> String) {
        do {
            let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
            let updated = transform(content)
            guard updated != content else { return }
            try updated.write(toFile: hostsPath, atomically: false, encoding: .utf8)
            flushDNS()
            NSLog("[bori] %@", success)
        } catch {
            NSLog("[bori] the hosts file could not be changed (%@) — run Bori as administrator to put sites away", "\(error)")
        }
    }

    private func flushDNS() {
        let root = ProcessInfo.processInfo.environment["SystemRoot"] ?? "C:\\Windows"
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "\(root)\\System32\\ipconfig.exe")
        process.arguments = ["/flushdns"]
        try? process.run()
        process.waitUntilExit()
    }
}
#endif
