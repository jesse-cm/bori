import Foundation

/// Stand-in for the privileged SMAppService helper. Until that is wired,
/// this prints exactly what the helper would write to /etc/hosts.
final class HostsHelperStub {
    private(set) var blocked: [String] = []

    func block(_ hosts: [String]) {
        guard !hosts.isEmpty else { return }
        blocked = hosts
        var entries: [String] = ["# bori:begin"]
        for host in hosts {
            entries.append("0.0.0.0 \(host)")
            if !host.hasPrefix("www.") {
                entries.append("0.0.0.0 www.\(host)")
            }
        }
        entries.append("# bori:end")
        NSLog("[bori] hosts helper (stub) — a privileged helper would append to /etc/hosts:")
        for line in entries { NSLog("[bori]   %@", line) }
        NSLog("[bori] hosts helper (stub) — then flush DNS: dscacheutil -flushcache; killall -HUP mDNSResponder")
    }

    func unblock() {
        guard !blocked.isEmpty else { return }
        NSLog("[bori] hosts helper (stub) — a privileged helper would remove the bori block from /etc/hosts and flush DNS")
        blocked = []
    }
}
