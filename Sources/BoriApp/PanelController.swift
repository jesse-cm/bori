#if os(macOS)
import AppKit
import WebKit

/// A borderless, sharp-cornered dropdown under the status item.
/// The page draws its own border; the window contributes nothing —
/// no chrome, no shadow, per the design.
final class PanelController: NSObject, WKScriptMessageHandler, WKNavigationDelegate {
    private final class Panel: NSPanel {
        override var canBecomeKey: Bool { true }
    }

    private let panel: Panel
    private let webView: WKWebView
    private let onAction: (String) -> Void
    private var clickMonitor: Any?
    private var lastHTML = ""
    private var anchorTop: CGFloat = 0
    private var anchorRight: CGFloat = 0

    var isVisible: Bool { panel.isVisible }

    init(onAction: @escaping (String) -> Void) {
        self.onAction = onAction

        let configuration = WKWebViewConfiguration()
        webView = WKWebView(
            frame: NSRect(x: 0, y: 0, width: PanelHTML.panelWidth, height: 420),
            configuration: configuration
        )
        webView.setValue(false, forKey: "drawsBackground")

        panel = Panel(
            contentRect: webView.frame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = .popUpMenu
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.contentView = webView

        super.init()
        configuration.userContentController.add(self, name: "bori")
        webView.navigationDelegate = self
    }

    func toggle(below button: NSStatusBarButton, html: String) {
        if panel.isVisible {
            hide()
        } else {
            show(below: button, html: html)
        }
    }

    func show(below button: NSStatusBarButton, html: String) {
        guard let buttonWindow = button.window else { return }
        let screen = buttonWindow.screen ?? NSScreen.main
        let frame = buttonWindow.frame
        anchorTop = frame.minY - 6
        anchorRight = frame.maxX
        if let visible = screen?.visibleFrame {
            anchorRight = min(anchorRight, visible.maxX - 8)
        }
        lastHTML = ""
        render(html: html)
        place(height: max(panel.frame.height, 300))
        panel.makeKeyAndOrderFront(nil)
        installClickMonitor()
    }

    func hide() {
        panel.orderOut(nil)
        if let monitor = clickMonitor {
            NSEvent.removeMonitor(monitor)
            clickMonitor = nil
        }
    }

    /// Re-renders only when the content actually changed.
    func render(html: String) {
        guard html != lastHTML else { return }
        lastHTML = html
        webView.loadHTMLString(html, baseURL: nil)
    }

    // MARK: - Layout

    private func place(height: CGFloat) {
        let x = max(anchorRight - PanelHTML.panelWidth, 8)
        panel.setFrame(
            NSRect(x: x, y: anchorTop - height, width: PanelHTML.panelWidth, height: height),
            display: true
        )
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        webView.evaluateJavaScript("document.getElementById('panel').offsetHeight") { [weak self] value, _ in
            guard let self, let number = value as? NSNumber else { return }
            let height = CGFloat(truncating: number)
            if height > 0 { self.place(height: height) }
        }
    }

    // MARK: - Bridge

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == "bori", let action = message.body as? String else { return }
        onAction(action)
    }

    private func installClickMonitor() {
        guard clickMonitor == nil else { return }
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            self?.hide()
        }
    }
}
#endif
