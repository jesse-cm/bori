#if os(macOS)
import Foundation

struct MenuLine: Equatable {
    var html: String
    var action: String?
    var unavailable = false
}

struct PanelModel: Equatable {
    enum Pose: String { case sit, sleep }

    var mode: String        // "light" | "dark"
    var pose: Pose
    var statusHTML: String
    var detailHTML: String?
    var menu: [MenuLine]
}

/// Renders the dropdown as a self-contained page around theme.css and
/// bori-screen.js (the canonical design files, bundled as resources).
enum PanelHTML {
    static let panelWidth: CGFloat = 260

    static let css = load("theme", "css")
    static let js = load("bori-screen", "js")

    private static func load(_ name: String, _ ext: String) -> String {
        guard let url = Bundle.module.url(forResource: name, withExtension: ext),
              let text = try? String(contentsOf: url, encoding: .utf8) else {
            NSLog("[bori] resource %@.%@ was missing from the bundle", name, ext)
            return ""
        }
        return text
    }

    static func page(_ model: PanelModel) -> String {
        var menuHTML = ""
        for line in model.menu {
            let cls = line.unavailable ? "menu-item unavailable" : "menu-item"
            let action = line.action.map { " data-action=\"\($0)\"" } ?? ""
            menuHTML += "<div class=\"\(cls)\"\(action)>\(line.html)</div>\n"
        }
        let detail = model.detailHTML.map { "<div class=\"detail\">\($0)</div>" } ?? ""
        return """
        <!doctype html>
        <html data-mode="\(model.mode)">
        <head>
        <meta charset="utf-8">
        <style>\(css)</style>
        <style>
          html, body { margin: 0; padding: 0; background: transparent; overflow: hidden; }
          body { -webkit-user-select: none; user-select: none; cursor: default; }
        </style>
        </head>
        <body>
          <div class="panel" id="panel">
            <div class="screen" id="screen"></div>
            <div class="status">\(model.statusHTML)</div>
            \(detail)
            <div class="menu">\(menuHTML)</div>
          </div>
          <script>\(js)</script>
          <script>
            renderBori(document.getElementById('screen'), '\(model.pose.rawValue)');
            document.querySelectorAll('.menu-item[data-action]').forEach(function (el) {
              el.addEventListener('click', function () {
                window.webkit.messageHandlers.bori.postMessage(el.getAttribute('data-action'));
              });
            });
          </script>
        </body>
        </html>
        """
    }
}
#endif
