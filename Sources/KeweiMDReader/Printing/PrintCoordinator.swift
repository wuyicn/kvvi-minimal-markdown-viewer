import AppKit
import WebKit

@MainActor
struct PrintCoordinator {
    func operation(for webView: WKWebView) -> NSPrintOperation? {
        webView.printOperation(with: NSPrintInfo.shared)
    }

    func print(_ webView: WKWebView) {
        operation(for: webView)?.run()
    }
}
