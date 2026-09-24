import XCTest
@testable import KeweiMDReader

@MainActor
final class OpenDocumentBrokerTests: XCTestCase {
    func testKeepsLatestURLUntilUIConsumesIt() {
        let broker = OpenDocumentBroker()
        let url = URL(fileURLWithPath: "/tmp/startup.md")
        broker.enqueue(url)
        XCTAssertEqual(broker.pendingURL, url)
        broker.markConsumed(url)
        XCTAssertNil(broker.pendingURL)
    }
}

