import CryptoKit
import XCTest
@testable import KeweiMDReader

final class DocumentLoaderTests: XCTestCase {
    private func temporaryFile(name: String, bytes: Data) throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent(name)
        try bytes.write(to: url)
        return url
    }

    func testLoadsUTF8BOMCRLFAndEmptyFiles() throws {
        let cases: [(String, Data, String)] = [
            ("bom.md", Data([0xEF, 0xBB, 0xBF]) + Data("# 中文".utf8), "# 中文"),
            ("crlf.markdown", Data("A\r\nB".utf8), "A\r\nB"),
            ("empty.md", Data(), "")
        ]
        for (name, bytes, expected) in cases {
            XCTAssertEqual(
                try DocumentLoader().load(from: temporaryFile(name: name, bytes: bytes)).text,
                expected
            )
        }
    }

    func testRejectsWrongExtensionInvalidEncodingAndOversizedFile() throws {
        XCTAssertThrowsError(try DocumentLoader().load(
            from: temporaryFile(name: "note.txt", bytes: Data("hello".utf8))
        )) { XCTAssertEqual($0 as? ReaderError, .unsupportedFileType) }
        XCTAssertThrowsError(try DocumentLoader().load(
            from: temporaryFile(name: "bad.md", bytes: Data([0xFF, 0xFE, 0x00]))
        )) { XCTAssertEqual($0 as? ReaderError, .unsupportedEncoding) }
        XCTAssertThrowsError(try DocumentLoader().load(
            from: temporaryFile(name: "large.md", bytes: Data(repeating: 65, count: 11)),
            maxBytes: 10
        )) { XCTAssertEqual($0 as? ReaderError, .fileTooLarge) }
    }

    func testLoadDoesNotChangeSourceBytes() throws {
        let url = try temporaryFile(name: "note.md", bytes: Data("# 不可修改".utf8))
        let before = SHA256.hash(data: try Data(contentsOf: url))
        _ = try DocumentLoader().load(from: url)
        let after = SHA256.hash(data: try Data(contentsOf: url))
        XCTAssertEqual(before, after)
    }
}
