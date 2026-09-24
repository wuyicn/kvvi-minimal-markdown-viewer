import Foundation
import UniformTypeIdentifiers
import WebKit

struct ResolvedImage {
    let data: Data
    let mimeType: String
}

enum LocalImageError: Error {
    case invalidPath
    case unsupportedType
    case tooLarge
    case unreadable
}

struct LocalImageResolver: Sendable {
    let baseDirectory: URL
    var maximumBytes = 20 * 1024 * 1024

    func resolve(_ encodedPath: String) throws -> ResolvedImage {
        guard let decoded = encodedPath.removingPercentEncoding,
              !decoded.hasPrefix("/") else {
            throw LocalImageError.invalidPath
        }

        let root = baseDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let target = root
            .appendingPathComponent(decoded)
            .standardizedFileURL
            .resolvingSymlinksInPath()
        guard target.path.hasPrefix(root.path + "/") else {
            throw LocalImageError.invalidPath
        }
        guard let type = UTType(filenameExtension: target.pathExtension),
              type.conforms(to: .image),
              let mimeType = type.preferredMIMEType else {
            throw LocalImageError.unsupportedType
        }
        guard let values = try? target.resourceValues(
            forKeys: [.isRegularFileKey, .fileSizeKey]
        ), values.isRegularFile == true else {
            throw LocalImageError.unreadable
        }
        guard (values.fileSize ?? 0) <= maximumBytes else {
            throw LocalImageError.tooLarge
        }
        guard let data = try? Data(contentsOf: target, options: [.mappedIfSafe]) else {
            throw LocalImageError.unreadable
        }
        return ResolvedImage(data: data, mimeType: mimeType)
    }
}

final class LocalImageSchemeHandler: NSObject, WKURLSchemeHandler, @unchecked Sendable {
    private let lock = NSLock()
    private var baseDirectory: URL

    init(baseDirectory: URL) {
        self.baseDirectory = baseDirectory
    }

    func updateBaseDirectory(_ url: URL) {
        lock.withLock {
            baseDirectory = url
        }
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: any WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(LocalImageError.invalidPath)
            return
        }
        let root = lock.withLock { baseDirectory }
        let encodedPath = String(url.path.dropFirst())
        do {
            let image = try LocalImageResolver(baseDirectory: root).resolve(encodedPath)
            let response = URLResponse(
                url: url,
                mimeType: image.mimeType,
                expectedContentLength: image.data.count,
                textEncodingName: nil
            )
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didReceive(image.data)
            urlSchemeTask.didFinish()
        } catch {
            urlSchemeTask.didFailWithError(error)
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: any WKURLSchemeTask) {}
}
