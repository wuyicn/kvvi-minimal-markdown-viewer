import ObjectiveC
import WebKit
import XCTest
@testable import KeweiMDReader

@MainActor
final class PrintCoordinatorTests: XCTestCase {
    func testCreatesPrintOperationForLoadedWebView() async throws {
        let webView = WKWebView()
        try await load(html: "<h1>可打印内容</h1>", into: webView)

        XCTAssertNotNil(PrintCoordinator().operation(for: webView))
    }

    private func load(html: String, into webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = PrintNavigationFinishDelegate(continuation: continuation)
            objc_setAssociatedObject(
                webView,
                Unmanaged.passUnretained(self).toOpaque(),
                delegate,
                .OBJC_ASSOCIATION_RETAIN_NONATOMIC
            )
            webView.navigationDelegate = delegate
            webView.loadHTMLString(html, baseURL: nil)
        }
    }
}

@MainActor
private final class PrintNavigationFinishDelegate: NSObject, WKNavigationDelegate {
    private var continuation: CheckedContinuation<Void, Error>?

    init(continuation: CheckedContinuation<Void, Error>) {
        self.continuation = continuation
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        continuation?.resume()
        continuation = nil
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        continuation?.resume(throwing: error)
        continuation = nil
    }
}
