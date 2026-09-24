import XCTest
@testable import KeweiMDReader

final class ResourceBundleTests: XCTestCase {
    func testBundledRendererAndStylesExist() throws {
        XCTAssertNotNil(Bundle.module.url(
            forResource: "markdown-it.umd.min",
            withExtension: "js"
        ))
        XCTAssertNotNil(Bundle.module.url(
            forResource: "reader",
            withExtension: "css"
        ))
    }
}
