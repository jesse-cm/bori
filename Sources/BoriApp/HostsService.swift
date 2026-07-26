import Foundation
import ServiceManagement
import BoriHelperCore

/// App-side face of the privileged helper. Registration happens once at
/// launch; macOS then lists the helper in System Settings → Login Items
/// awaiting a one-time approval. Until it is approved, blocking is
/// logged but not enforced — surfaced in the panel as a text line,
/// never a prompt.
final class HostsService {
    private let service = SMAppService.daemon(plistName: BoriHelperConstants.plistName)
    private var connection: NSXPCConnection?

    var isReady: Bool { service.status == .enabled }

    var statusDescription: String {
        switch service.status {
        case .enabled: return "enabled"
        case .requiresApproval: return "awaiting approval in Login Items"
        case .notRegistered: return "not registered"
        case .notFound: return "not found in the bundle"
        @unknown default: return "unknown"
        }
    }

    func registerIfNeeded() {
        guard service.status != .enabled else { return }
        do {
            try service.register()
            NSLog("[bori] hosts helper registered — %@", statusDescription)
        } catch {
            NSLog("[bori] the hosts helper could not be registered (%@) — %@",
                  "\(error)", statusDescription)
        }
    }

    func openLoginItems() {
        SMAppService.openSystemSettingsLoginItems()
    }

    func block(_ hosts: [String], until end: Date?) {
        guard !hosts.isEmpty else { return }
        guard isReady else {
            NSLog("[bori] sites were not put away — the helper is %@", statusDescription)
            return
        }
        proxy()?.setBlockedHosts(hosts, untilEpoch: end?.timeIntervalSince1970 ?? 0) { error in
            if let error {
                NSLog("[bori] /etc/hosts could not be updated: %@", error)
            } else {
                NSLog("[bori] %d sites were put away", hosts.count)
            }
        }
    }

    func unblock() {
        guard isReady else { return }
        proxy()?.clearBlockedHosts { error in
            if let error {
                NSLog("[bori] /etc/hosts could not be restored: %@", error)
            } else {
                NSLog("[bori] the sites were returned")
            }
        }
    }

    private func proxy() -> BoriHelperProtocol? {
        if connection == nil {
            let c = NSXPCConnection(
                machServiceName: BoriHelperConstants.machServiceName,
                options: .privileged
            )
            c.remoteObjectInterface = NSXPCInterface(with: BoriHelperProtocol.self)
            c.invalidationHandler = { [weak self] in self?.connection = nil }
            c.resume()
            connection = c
        }
        return connection?.remoteObjectProxyWithErrorHandler { error in
            NSLog("[bori] the hosts helper was unreachable: %@", "\(error)")
        } as? BoriHelperProtocol
    }
}
