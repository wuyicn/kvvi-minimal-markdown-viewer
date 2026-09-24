import AppKit
import SwiftUI
import WebKit

struct ReaderWebView: NSViewRepresentable {
    let document: LoadedDocument
    let fontSize: Int
    var onReady: ((WKWebView) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(baseDirectory: document.baseDirectory)
    }

    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = false
        configuration.setURLSchemeHandler(
            context.coordinator.imageHandler,
            forURLScheme: "kewei-image"
        )

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.allowsMagnification = false
        context.coordinator.onReady = onReady
        context.coordinator.load(document, fontSize: fontSize, in: webView)
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        context.coordinator.onReady = onReady
        context.coordinator.load(document, fontSize: fontSize, in: webView)
    }

    @MainActor
    final class Coordinator: NSObject, WKNavigationDelegate {
        let imageHandler: LocalImageSchemeHandler
        var onReady: ((WKWebView) -> Void)?
        private var loadedSignature: String?
        private var appliedFontSize: Int?
        private var desiredFontSize = 17

        init(baseDirectory: URL) {
            imageHandler = LocalImageSchemeHandler(baseDirectory: baseDirectory)
        }

        func load(_ document: LoadedDocument, fontSize: Int, in webView: WKWebView) {
            let signature = document.url.path + ":" + String(document.text.hashValue)
            desiredFontSize = min(max(fontSize, 14), 28)
            if loadedSignature != signature {
                loadedSignature = signature
                appliedFontSize = nil
                imageHandler.updateBaseDirectory(document.baseDirectory)
                do {
                    let html = try ReaderHTMLBuilder().build(markdown: document.text)
                    webView.loadHTMLString(html, baseURL: nil)
                } catch {
                    webView.loadHTMLString(
                        "<meta charset=\"utf-8\"><p>无法显示该文件</p>",
                        baseURL: nil
                    )
                }
                return
            }

            applyFontSizeIfNeeded(in: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            applyFontSizeIfNeeded(in: webView)
            onReady?(webView)
        }

        private func applyFontSizeIfNeeded(in webView: WKWebView) {
            guard appliedFontSize != desiredFontSize else { return }
            appliedFontSize = desiredFontSize
            webView.evaluateJavaScript(
                "document.documentElement.style.setProperty('--reader-font-size', '\(desiredFontSize)px')"
            )
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping @MainActor @Sendable (WKNavigationActionPolicy) -> Void
        ) {
            switch NavigationPolicy.decision(
                for: navigationAction.request.url,
                navigationType: navigationAction.navigationType
            ) {
            case .allow:
                decisionHandler(.allow)
            case .cancel:
                decisionHandler(.cancel)
            case .openExternally(let url):
                NSWorkspace.shared.open(url)
                decisionHandler(.cancel)
            }
        }
    }
}
