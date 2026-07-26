import Foundation
import BoriHelperCore

/// The privileged helper. launchd starts it as root on demand (see the
/// LaunchDaemons plist in the app bundle); it edits the bori marker
/// block in /etc/hosts, flushes DNS, and nothing else.

final class HelperService: NSObject, BoriHelperProtocol {
    private let hostsPath = "/etc/hosts"
    private var expiry: DispatchWorkItem?

    func setBlockedHosts(_ hosts: [String], untilEpoch: Double, reply: @escaping (String?) -> Void) {
        let invalid = hosts.filter { !HostsFile.isValidHost($0) }
        guard invalid.isEmpty else {
            reply("these host names were not understood: \(invalid.joined(separator: ", "))")
            return
        }
        do {
            try rewrite { HostsFile.applying(hosts, to: $0) }
            scheduleExpiry(atEpoch: untilEpoch)
            reply(nil)
        } catch {
            reply("\(error)")
        }
    }

    func clearBlockedHosts(reply: @escaping (String?) -> Void) {
        expiry?.cancel()
        expiry = nil
        do {
            try rewrite { HostsFile.removingBlock(from: $0) }
            reply(nil)
        } catch {
            reply("\(error)")
        }
    }

    /// Safety net: if the app never asks to clear (crash, power loss),
    /// the block lapses on its own at the session's end.
    private func scheduleExpiry(atEpoch epoch: Double) {
        expiry?.cancel()
        expiry = nil
        guard epoch > 0 else { return }
        let delay = epoch - Date().timeIntervalSince1970
        guard delay > 0 else { return }
        let work = DispatchWorkItem { [weak self] in
            try? self?.rewrite { HostsFile.removingBlock(from: $0) }
        }
        expiry = work
        DispatchQueue.global().asyncAfter(deadline: .now() + delay + 1, execute: work)
    }

    private func rewrite(_ transform: (String) -> String) throws {
        let content = try String(contentsOfFile: hostsPath, encoding: .utf8)
        let updated = transform(content)
        guard updated != content else { return }
        try updated.write(toFile: hostsPath, atomically: true, encoding: .utf8)
        try? FileManager.default.setAttributes([.posixPermissions: 0o644], ofItemAtPath: hostsPath)
        flushDNS()
    }

    private func flushDNS() {
        for (tool, arguments) in [
            ("/usr/bin/dscacheutil", ["-flushcache"]),
            ("/usr/bin/killall", ["-HUP", "mDNSResponder"]),
        ] {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: tool)
            process.arguments = arguments
            try? process.run()
            process.waitUntilExit()
        }
    }
}

final class HelperDelegate: NSObject, NSXPCListenerDelegate {
    private let service = HelperService()

    func listener(_ listener: NSXPCListener, shouldAcceptNewConnection newConnection: NSXPCConnection) -> Bool {
        newConnection.exportedInterface = NSXPCInterface(with: BoriHelperProtocol.self)
        newConnection.exportedObject = service
        newConnection.resume()
        return true
    }
}

guard geteuid() == 0 else {
    NSLog("[bori-helper] not running as root; exiting")
    exit(1)
}

let listener = NSXPCListener(machServiceName: BoriHelperConstants.machServiceName)
let delegate = HelperDelegate()
listener.delegate = delegate
listener.resume()
RunLoop.main.run()
