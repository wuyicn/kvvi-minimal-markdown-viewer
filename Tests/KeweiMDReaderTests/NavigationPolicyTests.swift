import WebKit
import XCTest
@testable import KeweiMDReader

final class NavigationPolicyTests: XCTestCase {
    func testUserClickedHTTPLinkOpensExternally() {
        let url = URL(string: "https://example.com")!
        XCTAssertEqual(
            NavigationPolicy.decision(for: url, navigationType: .linkActivated),
            .openExternally(url)
        )
    }

    func testBlocksAutomaticHTTPAndUnsafeSchemes() {
        XCTAssertEqual(
            NavigationPolicy.decision(
                for: URL(string: "https://example.com/image.png")!,
                navigationType: .other
            ),
            .cancel
        )
        XCTAssertEqual(
            NavigationPolicy.decision(
                for: URL(string: "javascript:alert(1)")!,
                navigationType: .linkActivated
            ),
            .cancel
        )
    }

    func testAllowsReaderInternalURLs() {
        XCTAssertEqual(
            NavigationPolicy.decision(
                for: URL(string: "about:blank")!,
                navigationType: .other
            ),
            .allow
        )
        XCTAssertEqual(
            NavigationPolicy.decision(
                for: URL(string: "kewei-image://local/a.png")!,
                navigationType: .other
            ),
            .allow
        )
    }
}
