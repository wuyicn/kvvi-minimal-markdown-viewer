import ObjectiveC
import WebKit
import XCTest
@testable import KeweiMDReader

@MainActor
final class WebRendererIntegrationTests: XCTestCase {
    func testWebViewRendersSupportedMarkdownWithoutExecutingRawHTML() async throws {
        let markdown = """
        # 标题
        |a|b|
        |---|---|
        |1|2|
        - [x] 完成
        <script>window.pwned=true</script>
        ![远程](https://example.com/a.png)
        """
        let html = try ReaderHTMLBuilder().build(markdown: markdown)
        let webView = WKWebView(frame: .zero)
        try await load(html: html, into: webView)

        let value = try await webView.callAsyncJavaScript(
            """
            return {
              heading: document.querySelector('h1')?.textContent || '',
              tableCount: document.querySelectorAll('table').length,
              checkedTaskCount: document.querySelectorAll('input[type=checkbox]:checked:disabled').length,
              pwned: typeof window.pwned !== 'undefined',
              remotePlaceholderCount: document.querySelectorAll('.remote-image').length
            };
            """,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        let snapshot = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(snapshot["heading"] as? String, "标题")
        XCTAssertEqual(snapshot["tableCount"] as? Int, 1)
        XCTAssertEqual(snapshot["checkedTaskCount"] as? Int, 1)
        XCTAssertEqual(snapshot["pwned"] as? Bool, false)
        XCTAssertEqual(snapshot["remotePlaceholderCount"] as? Int, 1)
    }

    private func load(html: String, into webView: WKWebView) async throws {
        try await withCheckedThrowingContinuation { continuation in
            let delegate = NavigationFinishDelegate(continuation: continuation)
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
private final class NavigationFinishDelegate: NSObject, WKNavigationDelegate {
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
