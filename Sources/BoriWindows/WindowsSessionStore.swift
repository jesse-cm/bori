#if os(Windows)
import Foundation

/// Same contract and file format as the macOS SessionStore:
/// %USERPROFILE%\Bori\session.json, so restarting the app is not a way
/// to end a session early.
enum WindowsSessionStore {
    private static var url: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Bori")
            .appendingPathComponent("session.json")
    }

    static func save(_ session: DateInterval?) {
        guard let session else { return clear() }
        let payload: [String: Double] = [
            "start": session.start.timeIntervalSince1970,
            "end": session.end.timeIntervalSince1970,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload) else { return }
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    static func restore(now: Date = Date()) -> DateInterval? {
        guard let data = try? Data(contentsOf: url),
              let payload = try? JSONSerialization.jsonObject(with: data) as? [String: Double],
              let start = payload["start"], let end = payload["end"],
              end > now.timeIntervalSince1970 else { return nil }
        return DateInterval(
            start: Date(timeIntervalSince1970: start),
            end: Date(timeIntervalSince1970: end)
        )
    }

    static func clear() {
        try? FileManager.default.removeItem(at: url)
    }
}
#endif
