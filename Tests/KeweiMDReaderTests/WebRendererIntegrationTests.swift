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

    func testReaderCoordinatorSignalsReadyAndAppliesFontAfterNavigation() async throws {
        let document = LoadedDocument(
            url: URL(fileURLWithPath: "/tmp/font.md"),
            text: "# 字号测试",
            baseDirectory: URL(fileURLWithPath: "/tmp")
        )
        let coordinator = ReaderWebView.Coordinator(baseDirectory: document.baseDirectory)
        let configuration = WKWebViewConfiguration()
        configuration.setURLSchemeHandler(
            coordinator.imageHandler,
            forURLScheme: "kewei-image"
        )
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = coordinator

        await withCheckedContinuation { continuation in
            coordinator.onReady = { readyWebView in
                XCTAssertIdentical(readyWebView, webView)
                continuation.resume()
            }
            coordinator.load(document, fontSize: 23, in: webView)
        }

        let value = try await webView.evaluateJavaScript(
            "getComputedStyle(document.documentElement).getPropertyValue('--reader-font-size').trim()"
        )
        XCTAssertEqual(value as? String, "23px")
        XCTAssertNotNil(PrintCoordinator().operation(for: webView))
    }

    func testReaderUsesCompactSoftTextAndTableVisualHierarchy() async throws {
        let markdown = """
        ## 阶段门禁
        正文包含 **重点内容**。

        | 门禁 | 条件 | 状态 |
        | --- | --- | --- |
        | G1 | 契约资产已搬入本仓库 | 已完成 |
        | G2 | 改造点清单已建立 | 已完成 |

        > 门禁的含义：未通过，下一阶段不得启动。
        """
        let html = try ReaderHTMLBuilder().build(markdown: markdown)
        let webView = WKWebView(frame: .zero)
        try await load(html: html, into: webView)

        let value = try await webView.callAsyncJavaScript(
            """
            const style = (selector) => getComputedStyle(document.querySelector(selector));
            return {
              bodyColor: style('body').color,
              headingColor: style('h2').color,
              strongColor: style('strong').color,
              tableFontSize: style('table').fontSize,
              headerBackground: style('th').backgroundColor,
              headerWeight: style('th').fontWeight,
              cellBorderColor: style('td').borderColor,
              cellPaddingTop: style('td').paddingTop,
              evenRowBackground: style('tbody tr:nth-child(2)').backgroundColor,
              quoteColor: style('blockquote').color
            };
            """,
            arguments: [:],
            in: nil,
            contentWorld: .page
        )
        let snapshot = try XCTUnwrap(value as? [String: Any])
        XCTAssertEqual(snapshot["bodyColor"] as? String, "rgb(58, 62, 68)")
        XCTAssertEqual(snapshot["headingColor"] as? String, "rgb(47, 52, 59)")
        XCTAssertEqual(snapshot["strongColor"] as? String, "rgb(47, 52, 59)")
        XCTAssertEqual(snapshot["tableFontSize"] as? String, "15.64px")
        XCTAssertEqual(snapshot["headerBackground"] as? String, "rgb(247, 248, 250)")
        XCTAssertEqual(snapshot["headerWeight"] as? String, "600")
        XCTAssertEqual(snapshot["cellBorderColor"] as? String, "rgb(223, 227, 232)")
        XCTAssertEqual(snapshot["cellPaddingTop"] as? String, "7px")
        XCTAssertEqual(snapshot["evenRowBackground"] as? String, "rgb(250, 251, 252)")
        XCTAssertEqual(snapshot["quoteColor"] as? String, "rgb(117, 124, 133)")
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
