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

    func testAppDelegateAcceptsModernOpenURLEvent() {
        let url = URL(fileURLWithPath: "/tmp/from-finder.md")

        AppDelegate().application(NSApplication.shared, open: [url])

        XCTAssertEqual(OpenDocumentBroker.shared.pendingURL, url)
        OpenDocumentBroker.shared.markConsumed(url)
    }
}
