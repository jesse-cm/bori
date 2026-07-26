import Foundation

/// Shared between the app and the privileged helper daemon.
public enum BoriHelperConstants {
    public static let machServiceName = "app.bori.helper"
    public static let plistName = "app.bori.helper.plist"
}

#if os(macOS)
/// The XPC surface of the helper. Deliberately tiny: set the blocked
/// hosts (with a deadline the daemon self-clears at, in case the app
/// never comes back), or clear them.
@objc public protocol BoriHelperProtocol {
    /// `untilEpoch` — seconds since 1970 when the block lapses on its
    /// own; pass 0 for no deadline. Replies with an error message, or
    /// nil on success.
    func setBlockedHosts(_ hosts: [String], untilEpoch: Double, reply: @escaping (String?) -> Void)
    func clearBlockedHosts(reply: @escaping (String?) -> Void)
}
#endif

/// Pure /etc/hosts editing around the bori marker block. No I/O here —
/// the daemon reads and writes; this only transforms text, so it is
/// fully unit-testable without root.
public enum HostsFile {
    public static let beginMarker = "# bori:begin"
    public static let endMarker = "# bori:end"

    /// Strict hostname shape — this is the injection barrier between
    /// config text and a root-owned file.
    public static func isValidHost(_ host: String) -> Bool {
        guard !host.isEmpty, host.count <= 253 else { return false }
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.lowercased().unicodeScalars.allSatisfy({ allowed.contains($0) }) else { return false }
        return !host.hasPrefix("-") && !host.hasPrefix(".") && !host.hasSuffix(".") && !host.contains("..")
    }

    public static func removingBlock(from content: String) -> String {
        var lines = content.components(separatedBy: "\n")
        while let begin = lines.firstIndex(of: beginMarker) {
            if let end = lines[begin...].firstIndex(of: endMarker) {
                lines.removeSubrange(begin...end)
            } else {
                lines.removeSubrange(begin...)
            }
        }
        while lines.count > 1, lines.last == "", lines[lines.count - 2] == "" {
            lines.removeLast()
        }
        return lines.joined(separator: "\n")
    }

    /// Replaces any existing bori block with one for `hosts`.
    /// Invalid names are dropped, never written.
    public static func applying(_ hosts: [String], to content: String) -> String {
        var base = removingBlock(from: content)
        let valid = hosts.filter(isValidHost)
        guard !valid.isEmpty else { return base }
        if !base.hasSuffix("\n") { base += "\n" }
        var block = [beginMarker]
        for host in valid {
            block.append("0.0.0.0 \(host)")
            if !host.hasPrefix("www.") {
                block.append("0.0.0.0 www.\(host)")
            }
        }
        block.append(endMarker)
        return base + block.joined(separator: "\n") + "\n"
    }
}
