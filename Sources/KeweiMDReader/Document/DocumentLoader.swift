import Foundation

struct LoadedDocument: Equatable, Sendable {
    let url: URL
    let text: String
    let baseDirectory: URL
}

struct DocumentLoader: Sendable {
    static let defaultMaximumBytes = 20 * 1024 * 1024

    func load(
        from url: URL,
        maxBytes: Int = DocumentLoader.defaultMaximumBytes
    ) throws -> LoadedDocument {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
            throw ReaderError.unsupportedFileType
        }
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true else {
            throw ReaderError.unreadableFile
        }
        guard (values.fileSize ?? 0) <= maxBytes else {
            throw ReaderError.fileTooLarge
        }
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw ReaderError.unreadableFile
        }

        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) {
            bytes.removeFirst(3)
        }
        guard let text = String(data: bytes, encoding: .utf8) else {
            throw ReaderError.unsupportedEncoding
        }
        return LoadedDocument(
            url: url,
            text: text,
            baseDirectory: url.deletingLastPathComponent()
        )
    }
}
