import XCTest
@testable import KeweiMDReader

@MainActor
final class ReaderViewModelTests: XCTestCase {
    func testShowsChineseErrorAndClampsFontSize() async {
        let model = ReaderViewModel(loader: DocumentLoader())
        await model.open(URL(fileURLWithPath: "/tmp/not-markdown.txt"))
        XCTAssertEqual(model.errorMessage, "请选择 Markdown 文件")
        for _ in 0..<20 { model.increaseFontSize() }
        XCTAssertEqual(model.fontSize, 28)
        for _ in 0..<20 { model.decreaseFontSize() }
        XCTAssertEqual(model.fontSize, 14)
    }
}
