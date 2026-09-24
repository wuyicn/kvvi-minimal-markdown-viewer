import XCTest
@testable import KeweiMDReader

final class LocalImageSchemeHandlerTests: XCTestCase {
    func testResolvesOnlyRegularImagesInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let image = root.appendingPathComponent("图片 1.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let resolver = LocalImageResolver(baseDirectory: root, maximumBytes: 1024)
        let result = try resolver.resolve("图片%201.png")
        XCTAssertEqual(result.mimeType, "image/png")
        XCTAssertEqual(result.data.count, 4)
    }

    func testRejectsTraversalSymlinkEscapeAndOversizedImage() throws {
        let parent = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let root = parent.appendingPathComponent("root")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let outside = parent.appendingPathComponent("outside.png")
        try Data(repeating: 1, count: 20).write(to: outside)
        try FileManager.default.createSymbolicLink(
            at: root.appendingPathComponent("escape.png"),
            withDestinationURL: outside
        )
        let inside = root.appendingPathComponent("large.png")
        try Data(repeating: 1, count: 20).write(to: inside)

        let resolver = LocalImageResolver(baseDirectory: root, maximumBytes: 10)
        XCTAssertThrowsError(try resolver.resolve("../outside.png"))
        XCTAssertThrowsError(try resolver.resolve("escape.png"))
        XCTAssertThrowsError(try resolver.resolve("large.png"))
    }
}
