#if os(macOS)
import Foundation

/// Writes dated, importable bookmarks files (Netscape format) to
/// ~/Bori/shelf/, one folder per browser window. Never reads them back —
/// the shelf is for the user, not the app.
final class ShelfWriter {
    static var shelfDirectory: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Bori")
            .appendingPathComponent("shelf")
    }

    static func snapshotCount() -> Int {
        let items = (try? FileManager.default.contentsOfDirectory(atPath: shelfDirectory.path)) ?? []
        return items.filter { $0.hasSuffix(".html") }.count
    }

    func write(_ windows: [WindowSnapshot], date: Date) throws -> String {
        let dir = Self.shelfDirectory
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

        let stamp = Int(date.timeIntervalSince1970)
        let nameFormatter = DateFormatter()
        nameFormatter.dateFormat = "yyyy-MM-dd-HHmm"
        var url = dir.appendingPathComponent("\(nameFormatter.string(from: date)).html")
        if FileManager.default.fileExists(atPath: url.path) {
            nameFormatter.dateFormat = "yyyy-MM-dd-HHmmss"
            url = dir.appendingPathComponent("\(nameFormatter.string(from: date)).html")
        }

        let titleFormatter = DateFormatter()
        titleFormatter.dateStyle = .long
        titleFormatter.timeStyle = .short

        var lines: [String] = [
            "<!DOCTYPE NETSCAPE-Bookmark-file-1>",
            "<!-- The shelf, written by Bori. Import into any browser, or read as it is. -->",
            "<META HTTP-EQUIV=\"Content-Type\" CONTENT=\"text/html; charset=UTF-8\">",
            "<TITLE>The shelf — \(escape(titleFormatter.string(from: date)))</TITLE>",
            "<H1>Shelved on \(escape(titleFormatter.string(from: date)))</H1>",
            "<DL><p>",
        ]
        for (index, window) in windows.enumerated() {
            let label = "\(window.browser.appName) — window \(index + 1) (\(window.tabs.count) tabs)"
            lines.append("    <DT><H3 ADD_DATE=\"\(stamp)\">\(escape(label))</H3>")
            lines.append("    <DL><p>")
            for tab in window.tabs {
                let title = tab.title.isEmpty ? tab.url : tab.title
                lines.append("        <DT><A HREF=\"\(escape(tab.url))\" ADD_DATE=\"\(stamp)\">\(escape(title))</A>")
            }
            lines.append("    </DL><p>")
        }
        lines.append("</DL><p>")

        try lines.joined(separator: "\n").appending("\n")
            .write(to: url, atomically: true, encoding: .utf8)
        NSLog("[bori] %d tabs were shelved to %@", windows.reduce(0) { $0 + $1.tabs.count }, url.path)
        return url.path
    }

    private func escape(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }
}
#endif
