import XCTest
@testable import KeweiMDReader

final class ReaderHTMLBuilderTests: XCTestCase {
    func testBuildsOfflineDocumentWithCSPAndEncodedSource() throws {
        let markdown = "# 标题\n</script><script>window.pwned=true</script>"
        let html = try ReaderHTMLBuilder().build(markdown: markdown)
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("img-src kewei-image: data:"))
        XCTAssertFalse(html.contains("const source = `# 标题"))
        XCTAssertFalse(html.contains("</script><script>window.pwned"))
        XCTAssertTrue(html.contains(#"\u003C"#))
        XCTAssertTrue(html.contains(#"\u003E"#))
        XCTAssertTrue(html.contains("html: false"))
    }

    func testBuilderContainsTableTaskAndRemoteImageRules() throws {
        let markdown = "|a|b|\n|-|-|\n|1|2|\n- [x] 完成\n![远程](https://example.com/a.png)"
        let html = try ReaderHTMLBuilder().build(markdown: markdown)
        XCTAssertTrue(html.contains("renderTaskLists"))
        XCTAssertTrue(html.contains("remote-image"))
        XCTAssertTrue(html.contains("kewei-image://local/"))
    }
}
