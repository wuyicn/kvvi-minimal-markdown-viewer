# 可微MD极简阅读器 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 构建一个可离线运行、只读且可作为 `.md` 默认打开程序的原生 macOS 应用“可微MD极简阅读器”。

**Architecture:** 使用 SwiftUI 构建窗口和工具栏，以 WKWebView 显示由内置 markdown-it 生成的安全 HTML。文件读取、HTML 生成、本地图片协议、链接导航、打印和 UI 状态分别放在独立组件中；应用不提供任何修改源文件的代码路径。

**Tech Stack:** Swift 6.3、SwiftUI、AppKit、WebKit、UniformTypeIdentifiers、Swift Package Manager、XCTest、markdown-it 15.0.2（MIT，随应用离线打包）、macOS 13+

**Spec:** `docs/superpowers/specs/2026-09-24-kewei-md-reader-design.md`

## Global Constraints

- 产品显示名称必须为“可微MD极简阅读器”。
- Bundle identifier 使用 `com.kewei.mdreader`。
- 最低系统版本为 macOS 13.0；首要构建目标为 Apple 芯片 arm64。
- 第一版是只读查看器：禁止编辑、保存、删除和覆盖源 Markdown 文件。
- Markdown、样式和脚本全部随应用打包；运行时不得从网络下载任何渲染资源。
- 禁止原始 HTML 和脚本执行；远程图片不自动下载；网页链接仅在用户点击后交给默认浏览器。
- 第一版支持 `.md` 和 `.markdown`、标题、段落、粗体、斜体、删除线、列表、引用、表格、代码、链接、任务列表、Emoji 和相对路径本地图片。
- 第一版不包含账号、同步、遥测、插件、主题市场、公式、Mermaid、多标签页、自动更新、App Store 发布或 Apple 公证。
- 任何用户可见错误必须为简明中文，不显示调用栈或底层异常文本。
- 第三方文件固定为 markdown-it 15.0.2；`markdown-it.umd.min.js` 的 SHA-256 必须为 `635972b985228e8af9f0143647c68616b7a3bb09f6946e7e4a52e43dcf5e7be5`。

## Review Focus

- 带 UTF-8 BOM、CRLF 或空内容的合法 Markdown 应正常打开；Task 2 的参数化测试固定该行为。
- 图片路径包含空格、中文、`..` 或符号链接时，合法目录内图片应显示，越界路径必须拒绝；Task 4 的路径测试固定该行为。
- Markdown 中的 `<script>`、`javascript:` 链接和远程图片不得执行或自动联网；Task 3 和 Task 5 的集成测试固定该行为。
- Finder 在应用 UI 创建前发送打开文件事件时，文件不得丢失；Task 6 的 broker 测试固定该行为。
- 阅读大文件或缺失图片时，应用不得卡死或崩溃，且原文件校验值不得变化；Task 2、Task 4 和 Task 7 的验收测试固定该行为。

---

## File Map

```text
Package.swift                                      SwiftPM 产品、平台、资源和测试目标
.gitignore                                         忽略 Swift 构建和本地发布产物
Sources/KeweiMDReader/App/KeweiMDReaderApp.swift   SwiftUI 应用入口与命令
Sources/KeweiMDReader/App/AppDelegate.swift        Finder 打开文件事件
Sources/KeweiMDReader/App/OpenDocumentBroker.swift 启动前后文件事件缓冲
Sources/KeweiMDReader/Document/ReaderError.swift   稳定的中文错误类型
Sources/KeweiMDReader/Document/DocumentLoader.swift只读文件校验与加载
Sources/KeweiMDReader/Rendering/ReaderHTMLBuilder.swift 组装安全 HTML
Sources/KeweiMDReader/Web/LocalImageSchemeHandler.swift 本地图片安全读取
Sources/KeweiMDReader/Web/NavigationPolicy.swift   WebView 导航判定
Sources/KeweiMDReader/Web/ReaderWebView.swift      WKWebView 桥接和渲染
Sources/KeweiMDReader/UI/ReaderViewModel.swift     阅读状态、字号和打开动作
Sources/KeweiMDReader/UI/ContentView.swift         空状态、工具栏和拖放
Sources/KeweiMDReader/Printing/PrintCoordinator.swift 系统打印
Sources/KeweiMDReader/Resources/reader.css         浅色/深色阅读样式
Sources/KeweiMDReader/Resources/markdown-it.umd.min.js 固定版本渲染器
Sources/KeweiMDReader/Resources/THIRD_PARTY_LICENSES.md 第三方许可
Tests/KeweiMDReaderTests/...                       单元和 WebKit 集成测试
Fixtures/sample.md                                 人工验收示例
Fixtures/images/sample.png                         相对路径图片样例
scripts/fetch_markdown_it.sh                       可复现的依赖获取和哈希校验
scripts/build_app.sh                               release 构建、App 打包、临时签名
scripts/smoke_test.sh                              App 包结构与只读烟雾测试
README.md                                          中文安装和使用说明
```

### Task 1: 建立可构建的 Swift 包和固定第三方资源

**Files:**
- Create: `.gitignore`
- Create: `Package.swift`
- Create: `Sources/KeweiMDReader/App/KeweiMDReaderApp.swift`
- Create: `Sources/KeweiMDReader/UI/ContentView.swift`
- Create: `Sources/KeweiMDReader/Resources/reader.css`
- Create: `Sources/KeweiMDReader/Resources/THIRD_PARTY_LICENSES.md`
- Create: `Sources/KeweiMDReader/Resources/markdown-it.umd.min.js`
- Create: `scripts/fetch_markdown_it.sh`
- Create: `Tests/KeweiMDReaderTests/ResourceBundleTests.swift`

**Interfaces:**
- Consumes: 无；这是项目根基。
- Produces: SwiftPM executable target `KeweiMDReader`、`Bundle.module` 资源访问方式、可验证的 markdown-it 固定资源。

- [ ] **Step 1: 写资源包失败测试**

```swift
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
```

- [ ] **Step 2: 创建最小 Package.swift 后运行测试，确认因资源不存在而失败**

```swift
// Package.swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "KeweiMDReader",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "KeweiMDReader", targets: ["KeweiMDReader"])],
    targets: [
        .executableTarget(
            name: "KeweiMDReader",
            resources: [.process("Resources")]
        ),
        .testTarget(
            name: "KeweiMDReaderTests",
            dependencies: ["KeweiMDReader"]
        )
    ]
)
```

Run: `swift test --filter ResourceBundleTests`

Expected: FAIL because `reader.css` and `markdown-it.umd.min.js` are absent.

同时创建 `.gitignore`：

```gitignore
.build/
dist/
.DS_Store
```

- [ ] **Step 3: 添加可复现的 markdown-it 获取脚本**

```bash
#!/bin/zsh
set -euo pipefail

readonly url='https://unpkg.com/markdown-it@15.0.2/dist/browser/markdown-it.umd.min.js'
readonly expected='635972b985228e8af9f0143647c68616b7a3bb09f6946e7e4a52e43dcf5e7be5'
readonly destination='Sources/KeweiMDReader/Resources/markdown-it.umd.min.js'

mkdir -p "${destination:h}"
curl --fail --location "$url" --output "$destination"
actual=$(shasum -a 256 "$destination" | awk '{print $1}')
[[ "$actual" == "$expected" ]] || {
  print -u2 "markdown-it 校验失败: $actual"
  exit 1
}
```

Run: `chmod +x scripts/fetch_markdown_it.sh && scripts/fetch_markdown_it.sh`

Expected: 脚本退出码为 0，文件哈希与 Global Constraints 一致。

- [ ] **Step 4: 添加最小应用入口、样式和第三方许可**

```swift
// Sources/KeweiMDReader/App/KeweiMDReaderApp.swift
import SwiftUI

@main
struct KeweiMDReaderApp: App {
    var body: some Scene {
        WindowGroup("可微MD极简阅读器") {
            ContentView()
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}
```

```swift
// Sources/KeweiMDReader/UI/ContentView.swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        ContentUnavailableView(
            "打开或拖入一个 Markdown 文件",
            systemImage: "doc.richtext"
        )
    }
}
```

```css
/* Sources/KeweiMDReader/Resources/reader.css */
:root { color-scheme: light dark; --reader-font-size: 17px; }
body {
  margin: 0 auto;
  padding: 44px 56px 80px;
  max-width: 880px;
  font: var(--reader-font-size)/1.75 -apple-system, BlinkMacSystemFont,
        "PingFang SC", "Helvetica Neue", sans-serif;
  color: #1f2328;
  background: #ffffff;
  overflow-wrap: anywhere;
}
table { width: 100%; border-collapse: collapse; }
th, td { border: 1px solid #d0d7de; padding: 8px 12px; text-align: left; }
pre { overflow-x: auto; padding: 16px; border-radius: 8px; background: #f6f8fa; }
blockquote { margin-left: 0; padding-left: 16px; border-left: 4px solid #d0d7de; color: #57606a; }
img { max-width: 100%; height: auto; }
.missing-image, .remote-image { color: #6e7781; font-style: italic; }
@media (prefers-color-scheme: dark) {
  body { color: #e6edf3; background: #0d1117; }
  pre { background: #161b22; }
  th, td { border-color: #30363d; }
  blockquote { border-color: #30363d; color: #8b949e; }
}
```

`THIRD_PARTY_LICENSES.md` 必须包含 markdown-it 15.0.2、MIT License 全文、项目主页和固定下载 URL。

- [ ] **Step 5: 运行测试和调试构建**

Run: `swift test && swift build`

Expected: 所有测试 PASS；`swift build` 成功生成 arm64 可执行文件。

- [ ] **Step 6: 提交任务 1**

```bash
git add .gitignore Package.swift Sources Tests scripts
git commit -m "build: scaffold macOS markdown reader"
```

### Task 2: 实现严格只读的 Markdown 文件加载

**Files:**
- Create: `Sources/KeweiMDReader/Document/ReaderError.swift`
- Create: `Sources/KeweiMDReader/Document/DocumentLoader.swift`
- Create: `Tests/KeweiMDReaderTests/DocumentLoaderTests.swift`

**Interfaces:**
- Consumes: Foundation `URL`。
- Produces: `LoadedDocument(url: URL, text: String, baseDirectory: URL)`；`DocumentLoader.load(from:maxBytes:) throws -> LoadedDocument`；`ReaderError.userMessage: String`。

- [ ] **Step 1: 写文件类型、BOM、CRLF、空文件、大文件和只读性测试**

```swift
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
            XCTAssertEqual(try DocumentLoader().load(from: temporaryFile(name: name, bytes: bytes)).text, expected)
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
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter DocumentLoaderTests`

Expected: FAIL because `DocumentLoader`, `LoadedDocument`, and `ReaderError` do not exist.

- [ ] **Step 3: 实现错误类型和加载器**

```swift
// ReaderError.swift
import Foundation

enum ReaderError: Error, Equatable {
    case unsupportedFileType
    case unreadableFile
    case unsupportedEncoding
    case fileTooLarge
    case renderFailed

    var userMessage: String {
        switch self {
        case .unsupportedFileType: return "请选择 Markdown 文件"
        case .unreadableFile: return "无法读取该文件"
        case .unsupportedEncoding: return "暂时无法识别该文件的文字编码"
        case .fileTooLarge: return "文件过大，暂时无法显示"
        case .renderFailed: return "无法显示该文件"
        }
    }
}
```

```swift
// DocumentLoader.swift
import Foundation

struct LoadedDocument: Equatable {
    let url: URL
    let text: String
    let baseDirectory: URL
}

struct DocumentLoader {
    static let defaultMaximumBytes = 20 * 1024 * 1024

    func load(from url: URL, maxBytes: Int = defaultMaximumBytes) throws -> LoadedDocument {
        guard ["md", "markdown"].contains(url.pathExtension.lowercased()) else {
            throw ReaderError.unsupportedFileType
        }
        guard let values = try? url.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
              values.isRegularFile == true else {
            throw ReaderError.unreadableFile
        }
        guard (values.fileSize ?? 0) <= maxBytes else { throw ReaderError.fileTooLarge }
        guard let data = try? Data(contentsOf: url, options: [.mappedIfSafe]) else {
            throw ReaderError.unreadableFile
        }
        var bytes = data
        if bytes.starts(with: [0xEF, 0xBB, 0xBF]) { bytes.removeFirst(3) }
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
```

- [ ] **Step 4: 运行全部测试**

Run: `swift test`

Expected: PASS。

- [ ] **Step 5: 提交任务 2**

```bash
git add Sources/KeweiMDReader/Document Tests/KeweiMDReaderTests/DocumentLoaderTests.swift
git commit -m "feat: load markdown documents read only"
```

### Task 3: 构建离线、安全的 Markdown HTML 文档

**Files:**
- Create: `Sources/KeweiMDReader/Rendering/ReaderHTMLBuilder.swift`
- Create: `Tests/KeweiMDReaderTests/ReaderHTMLBuilderTests.swift`

**Interfaces:**
- Consumes: `String` Markdown、`Bundle.module` 中的 JS/CSS。
- Produces: `ReaderHTMLBuilder.build(markdown:) throws -> String`，返回完整的自包含 HTML。

- [ ] **Step 1: 写 HTML 构建和注入防护测试**

```swift
import XCTest
@testable import KeweiMDReader

final class ReaderHTMLBuilderTests: XCTestCase {
    func testBuildsOfflineDocumentWithCSPAndEncodedSource() throws {
        let markdown = #"# 标题\n</script><script>window.pwned=true</script>"#
        let html = try ReaderHTMLBuilder().build(markdown: markdown)
        XCTAssertTrue(html.contains("default-src 'none'"))
        XCTAssertTrue(html.contains("img-src kewei-image: data:"))
        XCTAssertFalse(html.contains("const source = `# 标题"))
        XCTAssertFalse(html.contains("</script><script>window.pwned"))
        XCTAssertTrue(html.contains(#"\u003C/script\u003E"#))
        XCTAssertTrue(html.contains("html: false"))
    }

    func testBuilderContainsTableTaskAndRemoteImageRules() throws {
        let html = try ReaderHTMLBuilder().build(markdown: "|a|b|\n|-|-|\n|1|2|\n- [x] 完成\n![远程](https://example.com/a.png)")
        XCTAssertTrue(html.contains("renderTaskLists"))
        XCTAssertTrue(html.contains("remote-image"))
        XCTAssertTrue(html.contains("kewei-image://local/"))
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter ReaderHTMLBuilderTests`

Expected: FAIL because `ReaderHTMLBuilder` does not exist.

- [ ] **Step 3: 实现 HTML 构建器**

实现时使用 `JSONSerialization.data(withJSONObject:options:)` 生成 Markdown 的合法 JavaScript 字符串，不使用反引号拼接用户内容。核心模板必须包含以下逻辑：

```swift
import Foundation

struct ReaderHTMLBuilder {
    func build(markdown: String) throws -> String {
        guard let jsURL = Bundle.module.url(forResource: "markdown-it.umd.min", withExtension: "js"),
              let cssURL = Bundle.module.url(forResource: "reader", withExtension: "css"),
              let renderer = try? String(contentsOf: jsURL, encoding: .utf8),
              let css = try? String(contentsOf: cssURL, encoding: .utf8),
              let encodedData = try? JSONSerialization.data(withJSONObject: [markdown]),
              var encoded = String(data: encodedData, encoding: .utf8) else {
            throw ReaderError.renderFailed
        }
        encoded.removeFirst()
        encoded.removeLast()
        encoded = encoded
            .replacingOccurrences(of: "<", with: #"\u003C"#)
            .replacingOccurrences(of: ">", with: #"\u003E"#)
            .replacingOccurrences(of: "&", with: #"\u0026"#)
            .replacingOccurrences(of: "\u{2028}", with: #"\u2028"#)
            .replacingOccurrences(of: "\u{2029}", with: #"\u2029"#)

        return """
        <!doctype html><html><head><meta charset="utf-8">
        <meta http-equiv="Content-Security-Policy"
              content="default-src 'none'; img-src kewei-image: data:; style-src 'unsafe-inline'; script-src 'unsafe-inline'">
        <style>\(css)</style></head><body><main id="content"></main>
        <script>\(renderer)</script>
        <script>
        const source = \(encoded);
        const md = window.markdownit({ html: false, linkify: true, typographer: true, breaks: false });
        const defaultImage = md.renderer.rules.image;
        md.renderer.rules.image = function(tokens, index, options, env, self) {
          const src = tokens[index].attrGet('src') || '';
          if (/^https?:/i.test(src) || /^(javascript|file|data):/i.test(src)) {
            return '<span class="remote-image">[远程图片未加载]</span>';
          }
          tokens[index].attrSet('src', 'kewei-image://local/' + encodeURIComponent(src));
          return defaultImage(tokens, index, options, env, self);
        };
        function renderTaskLists(html) {
          return html
            .replace(/<li>\\s*(?:<p>)?\\[ \\]\\s*/gi, '<li class="task-item"><input type="checkbox" disabled> ')
            .replace(/<li>\\s*(?:<p>)?\\[[xX]\\]\\s*/g, '<li class="task-item"><input type="checkbox" checked disabled> ');
        }
        const content = document.getElementById('content');
        content.innerHTML = renderTaskLists(md.render(source));
        content.querySelectorAll('img').forEach((image) => {
          image.addEventListener('error', () => {
            const replacement = document.createElement('span');
            replacement.className = 'missing-image';
            replacement.textContent = '[图片无法显示]';
            image.replaceWith(replacement);
          });
        });
        </script></body></html>
        """
    }
}
```

- [ ] **Step 4: 运行构建器测试和全部测试**

Run: `swift test --filter ReaderHTMLBuilderTests && swift test`

Expected: PASS。

- [ ] **Step 5: 提交任务 3**

```bash
git add Sources/KeweiMDReader/Rendering Tests/KeweiMDReaderTests/ReaderHTMLBuilderTests.swift
git commit -m "feat: build secure offline markdown html"
```

### Task 4: 安全加载当前文档目录内的本地图片

**Files:**
- Create: `Sources/KeweiMDReader/Web/LocalImageSchemeHandler.swift`
- Create: `Tests/KeweiMDReaderTests/LocalImageSchemeHandlerTests.swift`

**Interfaces:**
- Consumes: 文档 `baseDirectory`、`kewei-image://local/<encoded-relative-path>` URL。
- Produces: `LocalImageResolver.resolve(_:) throws -> ResolvedImage(data:mimeType:)`；`LocalImageSchemeHandler` 将结果交给 WKWebView。

- [ ] **Step 1: 写合法路径、中文空格路径、越界、符号链接和大小限制测试**

```swift
import XCTest
@testable import KeweiMDReader

final class LocalImageSchemeHandlerTests: XCTestCase {
    func testResolvesOnlyRegularImagesInsideRoot() throws {
        let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let image = root.appendingPathComponent("图片 1.png")
        try Data([0x89, 0x50, 0x4E, 0x47]).write(to: image)
        let resolver = LocalImageResolver(baseDirectory: root, maximumBytes: 1024)
        let result = try resolver.resolve("图片 1.png")
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
        let resolver = LocalImageResolver(baseDirectory: root, maximumBytes: 10)
        XCTAssertThrowsError(try resolver.resolve("../outside.png"))
        XCTAssertThrowsError(try resolver.resolve("escape.png"))
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter LocalImageSchemeHandlerTests`

Expected: FAIL because resolver types do not exist.

- [ ] **Step 3: 实现路径解析器和 WKURLSchemeHandler**

路径校验必须先进行百分号解码，再使用 `standardizedFileURL.resolvingSymlinksInPath()`，并验证目标路径等于根目录或以 `root.path + "/"` 开头。只允许 `UTType(filenameExtension:)?.conforms(to: .image) == true` 的普通文件，默认图片上限 20 MB。

```swift
import Foundation
import UniformTypeIdentifiers
import WebKit

struct ResolvedImage { let data: Data; let mimeType: String }
enum LocalImageError: Error { case invalidPath, unsupportedType, tooLarge, unreadable }

struct LocalImageResolver {
    let baseDirectory: URL
    var maximumBytes = 20 * 1024 * 1024

    func resolve(_ encodedPath: String) throws -> ResolvedImage {
        guard let decoded = encodedPath.removingPercentEncoding,
              !decoded.hasPrefix("/") else { throw LocalImageError.invalidPath }
        let root = baseDirectory.standardizedFileURL.resolvingSymlinksInPath()
        let target = root.appendingPathComponent(decoded).standardizedFileURL.resolvingSymlinksInPath()
        guard target.path.hasPrefix(root.path + "/") else { throw LocalImageError.invalidPath }
        guard let type = UTType(filenameExtension: target.pathExtension), type.conforms(to: .image),
              let mime = type.preferredMIMEType else { throw LocalImageError.unsupportedType }
        let values = try target.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
        guard values.isRegularFile == true else { throw LocalImageError.unreadable }
        guard (values.fileSize ?? 0) <= maximumBytes else { throw LocalImageError.tooLarge }
        guard let data = try? Data(contentsOf: target, options: [.mappedIfSafe]) else {
            throw LocalImageError.unreadable
        }
        return ResolvedImage(data: data, mimeType: mime)
    }
}
```

`LocalImageSchemeHandler.start(_:urlSchemeTask:)` 必须从 `url.path.dropFirst()` 取得编码路径，成功时发送带 MIME 的 `URLResponse` 和数据；任何失败都调用 `didFailWithError`。`stop` 不执行副作用。handler 暴露 `updateBaseDirectory(_:)`，并用串行锁保护当前目录；ReaderWebView 在加载新文档前先更新目录，避免复用 WebView 时仍读取上一份文件的图片目录。

- [ ] **Step 4: 运行测试**

Run: `swift test --filter LocalImageSchemeHandlerTests && swift test`

Expected: PASS。

- [ ] **Step 5: 提交任务 4**

```bash
git add Sources/KeweiMDReader/Web/LocalImageSchemeHandler.swift Tests/KeweiMDReaderTests/LocalImageSchemeHandlerTests.swift
git commit -m "feat: load local markdown images safely"
```

### Task 5: 集成 WKWebView 并隔离外部导航

**Files:**
- Create: `Sources/KeweiMDReader/Web/NavigationPolicy.swift`
- Create: `Sources/KeweiMDReader/Web/ReaderWebView.swift`
- Create: `Tests/KeweiMDReaderTests/NavigationPolicyTests.swift`
- Create: `Tests/KeweiMDReaderTests/WebRendererIntegrationTests.swift`

**Interfaces:**
- Consumes: `LoadedDocument`、`ReaderHTMLBuilder`、`LocalImageSchemeHandler`。
- Produces: `NavigationPolicy.decision(for:navigationType:) -> ReaderNavigationDecision`；SwiftUI `ReaderWebView(document:fontSize:onReady:)`。

- [ ] **Step 1: 写导航策略测试**

```swift
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
        XCTAssertEqual(NavigationPolicy.decision(
            for: URL(string: "https://example.com/image.png")!, navigationType: .other
        ), .cancel)
        XCTAssertEqual(NavigationPolicy.decision(
            for: URL(string: "javascript:alert(1)")!, navigationType: .linkActivated
        ), .cancel)
    }

    func testAllowsReaderInternalURLs() {
        XCTAssertEqual(NavigationPolicy.decision(
            for: URL(string: "about:blank")!, navigationType: .other
        ), .allow)
        XCTAssertEqual(NavigationPolicy.decision(
            for: URL(string: "kewei-image://local/a.png")!, navigationType: .other
        ), .allow)
    }
}
```

- [ ] **Step 2: 运行导航测试，确认失败**

Run: `swift test --filter NavigationPolicyTests`

Expected: FAIL because navigation types do not exist.

- [ ] **Step 3: 实现纯导航策略**

```swift
import Foundation
import WebKit

enum ReaderNavigationDecision: Equatable {
    case allow
    case cancel
    case openExternally(URL)
}

enum NavigationPolicy {
    static func decision(for url: URL?, navigationType: WKNavigationType) -> ReaderNavigationDecision {
        guard let url, let scheme = url.scheme?.lowercased() else { return .cancel }
        if scheme == "about" || scheme == "kewei-image" { return .allow }
        if ["http", "https"].contains(scheme), navigationType == .linkActivated {
            return .openExternally(url)
        }
        return .cancel
    }
}
```

- [ ] **Step 4: 写 WebKit 渲染集成测试**

创建 `@MainActor` 测试，通过 `WKNavigationDelegate.didFinish` 等待加载完成，再用 `evaluateJavaScript` 检查：标题为 `H1`、表格存在、任务项包含禁用 checkbox、`window.pwned` 为 `undefined`、远程图片被替换成 `.remote-image`。

```swift
@MainActor
func testWebViewRendersSupportedMarkdownWithoutExecutingRawHTML() async throws {
    let markdown = "# 标题\n|a|b|\n|-|-|\n|1|2|\n- [x] 完成\n<script>window.pwned=true</script>\n![远程](https://example.com/a.png)"
    let webView = try TestWebViewLoader.load(html: ReaderHTMLBuilder().build(markdown: markdown))
    let snapshot = try await TestWebViewLoader.snapshot(from: webView)
    XCTAssertEqual(snapshot.heading, "标题")
    XCTAssertEqual(snapshot.tableCount, 1)
    XCTAssertEqual(snapshot.checkedTaskCount, 1)
    XCTAssertFalse(snapshot.pwned)
    XCTAssertEqual(snapshot.remotePlaceholderCount, 1)
}
```

- [ ] **Step 5: 实现 ReaderWebView 和 Coordinator**

`ReaderWebView` 使用 `NSViewRepresentable`。在 `makeNSView` 中创建 `WKWebViewConfiguration`、注册 `kewei-image` handler、关闭 inspector 和不需要的偏好；在 `updateNSView` 中仅当文档 URL 或内容变化时重新加载 HTML。Coordinator 实现：

```swift
func webView(
    _ webView: WKWebView,
    decidePolicyFor navigationAction: WKNavigationAction,
    decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
) {
    switch NavigationPolicy.decision(
        for: navigationAction.request.url,
        navigationType: navigationAction.navigationType
    ) {
    case .allow:
        decisionHandler(.allow)
    case .cancel:
        decisionHandler(.cancel)
    case .openExternally(let url):
        NSWorkspace.shared.open(url)
        decisionHandler(.cancel)
    }
}
```

字号变化时执行固定脚本，不拼接用户内容：

```swift
let clamped = min(max(fontSize, 14), 28)
webView.evaluateJavaScript(
    "document.documentElement.style.setProperty('--reader-font-size', '\(clamped)px')"
)
```

- [ ] **Step 6: 运行 WebKit 集成测试和全部测试**

Run: `swift test --filter NavigationPolicyTests && swift test --filter WebRendererIntegrationTests && swift test`

Expected: PASS；测试期间没有外部网络请求。

- [ ] **Step 7: 提交任务 5**

```bash
git add Sources/KeweiMDReader/Web Tests/KeweiMDReaderTests/NavigationPolicyTests.swift Tests/KeweiMDReaderTests/WebRendererIntegrationTests.swift
git commit -m "feat: render markdown in isolated web view"
```

### Task 6: 完成打开文件、拖放、字号和中文 UI 流程

**Files:**
- Create: `Sources/KeweiMDReader/App/OpenDocumentBroker.swift`
- Create: `Sources/KeweiMDReader/App/AppDelegate.swift`
- Create: `Sources/KeweiMDReader/UI/ReaderViewModel.swift`
- Modify: `Sources/KeweiMDReader/App/KeweiMDReaderApp.swift`
- Modify: `Sources/KeweiMDReader/UI/ContentView.swift`
- Create: `Tests/KeweiMDReaderTests/OpenDocumentBrokerTests.swift`
- Create: `Tests/KeweiMDReaderTests/ReaderViewModelTests.swift`

**Interfaces:**
- Consumes: `DocumentLoader`、`LoadedDocument`、`ReaderWebView`。
- Produces: `OpenDocumentBroker.shared` 缓冲 Finder 事件；`ReaderViewModel` 暴露 `document`、`errorMessage`、`isLoading`、`fontSize` 和打开动作。

- [ ] **Step 1: 写启动前事件和 ViewModel 状态测试**

```swift
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
```

- [ ] **Step 2: 运行状态测试，确认失败**

Run: `swift test --filter OpenDocumentBrokerTests && swift test --filter ReaderViewModelTests`

Expected: FAIL because broker and view model do not exist.

- [ ] **Step 3: 实现事件缓冲和 Finder 打开事件**

```swift
@MainActor
final class OpenDocumentBroker: ObservableObject {
    static let shared = OpenDocumentBroker()
    @Published private(set) var pendingURL: URL?
    func enqueue(_ url: URL) { pendingURL = url }
    func markConsumed(_ url: URL) { if pendingURL == url { pendingURL = nil } }
}
```

`AppDelegate.application(_:openFiles:)` 只接受第一个路径，转成文件 URL 后调用 `OpenDocumentBroker.shared.enqueue(url)`，随后调用 `sender.reply(toOpenOrPrint: .success)`；没有文件时回复 `.failure`。

- [ ] **Step 4: 实现 ReaderViewModel**

`open(_:)` 必须在加载前设置 `isLoading = true`，使用 `Task.detached` 调用同步 loader，回到 MainActor 后设置 document 或 `ReaderError.userMessage`，最后设置 `isLoading = false`。字号默认 17，范围 14...28，每次变化 1。

```swift
@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var document: LoadedDocument?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var fontSize = 17
    private let loader: DocumentLoader

    init(loader: DocumentLoader = DocumentLoader()) { self.loader = loader }
    func increaseFontSize() { fontSize = min(fontSize + 1, 28) }
    func decreaseFontSize() { fontSize = max(fontSize - 1, 14) }
}
```

- [ ] **Step 5: 实现极简 ContentView**

UI 只包含：空状态、“打开文件”按钮、当前文件名、缩小、放大、打印和 ReaderWebView。文件选择使用 `NSOpenPanel`，限制 `UTType(filenameExtension: "md")` 和 `UTType(filenameExtension: "markdown")`。拖放只接受 `.fileURL`，并调用同一个 `viewModel.open(_:)`。

```swift
.toolbar {
    ToolbarItemGroup {
        Button("打开文件", action: chooseFile)
        Text(viewModel.document?.url.lastPathComponent ?? "")
        Spacer()
        Button("缩小", systemImage: "textformat.size.smaller", action: viewModel.decreaseFontSize)
        Button("放大", systemImage: "textformat.size.larger", action: viewModel.increaseFontSize)
        Button("打印", systemImage: "printer", action: printDocument)
            .disabled(readerWebView == nil)
    }
}
```

错误使用 SwiftUI alert，标题“无法打开文件”，正文只用 `errorMessage`。加载期间显示 `ProgressView("正在打开…")`。

- [ ] **Step 6: 注入 AppDelegate 和 Broker**

```swift
@NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
@StateObject private var broker = OpenDocumentBroker.shared
```

ContentView 订阅 `broker.$pendingURL.compactMap { $0 }`，调用 `open` 成功或失败后都 `markConsumed`，保证应用启动前到达的 Finder 事件不会丢失。

- [ ] **Step 7: 运行测试和调试应用**

Run: `swift test && swift run KeweiMDReader`

Expected: 测试 PASS；显示中文空状态；打开与拖放示例 `.md` 均进入阅读状态；字号边界正确。

- [ ] **Step 8: 提交任务 6**

```bash
git add Sources/KeweiMDReader/App Sources/KeweiMDReader/UI Tests/KeweiMDReaderTests/OpenDocumentBrokerTests.swift Tests/KeweiMDReaderTests/ReaderViewModelTests.swift
git commit -m "feat: add simple Chinese reader workflow"
```

### Task 7: 打印、App 打包、示例和端到端验收

**Files:**
- Create: `Sources/KeweiMDReader/Printing/PrintCoordinator.swift`
- Create: `Fixtures/sample.md`
- Create: `Fixtures/images/sample.png`
- Create: `scripts/build_app.sh`
- Create: `scripts/smoke_test.sh`
- Create: `README.md`
- Modify: `Sources/KeweiMDReader/UI/ContentView.swift`
- Create: `Tests/KeweiMDReaderTests/PrintCoordinatorTests.swift`

**Interfaces:**
- Consumes: 已加载的 `WKWebView` 和 SwiftPM release 产品。
- Produces: `PrintCoordinator.print(_:)`、`dist/可微MD极简阅读器.app`、`dist/可微MD极简阅读器.zip`。

- [ ] **Step 1: 写打印可用性测试**

```swift
import WebKit
import XCTest
@testable import KeweiMDReader

@MainActor
final class PrintCoordinatorTests: XCTestCase {
    func testCreatesPrintOperationForWebView() {
        let webView = WKWebView()
        XCTAssertNotNil(PrintCoordinator().operation(for: webView))
    }
}
```

- [ ] **Step 2: 运行测试，确认失败**

Run: `swift test --filter PrintCoordinatorTests`

Expected: FAIL because `PrintCoordinator` does not exist.

- [ ] **Step 3: 实现系统打印**

```swift
import AppKit
import WebKit

@MainActor
struct PrintCoordinator {
    func operation(for webView: WKWebView) -> NSPrintOperation? {
        webView.printOperation(with: NSPrintInfo.shared)
    }

    func print(_ webView: WKWebView) {
        operation(for: webView)?.run()
    }
}
```

ContentView 的打印按钮调用此协调器；没有已完成加载的 WebView 时按钮保持禁用。

- [ ] **Step 4: 添加覆盖全部语法和图片的 Fixture**

`Fixtures/sample.md` 必须包含中文、英文、Emoji、六级标题、粗体、斜体、删除线、有序/无序列表、引用、表格、行内代码、代码块、外部链接、已选/未选任务、本地图片、缺失图片、远程图片和原始 `<script>`。`sample.png` 使用一个小型自制占位图，避免第三方版权资源。

- [ ] **Step 5: 编写 App 打包脚本**

`scripts/build_app.sh` 必须执行以下确定性步骤：

```bash
#!/bin/zsh
set -euo pipefail

readonly app_name='可微MD极简阅读器'
readonly bundle="dist/${app_name}.app"

swift build -c release --arch arm64
rm -rf "$bundle" "dist/${app_name}.zip"
mkdir -p "$bundle/Contents/MacOS" "$bundle/Contents/Resources"
cp '.build/arm64-apple-macosx/release/KeweiMDReader' "$bundle/Contents/MacOS/KeweiMDReader"
cp -R '.build/arm64-apple-macosx/release/KeweiMDReader_KeweiMDReader.bundle' "$bundle/Contents/Resources/"
```

随后使用 `/usr/libexec/PlistBuddy` 或 here-document 生成 `Contents/Info.plist`，精确包含：

```xml
<key>CFBundleDisplayName</key><string>可微MD极简阅读器</string>
<key>CFBundleExecutable</key><string>KeweiMDReader</string>
<key>CFBundleIdentifier</key><string>com.kewei.mdreader</string>
<key>CFBundlePackageType</key><string>APPL</string>
<key>CFBundleShortVersionString</key><string>1.0.0</string>
<key>CFBundleVersion</key><string>1</string>
<key>LSMinimumSystemVersion</key><string>13.0</string>
<key>CFBundleDocumentTypes</key>
<array><dict>
  <key>CFBundleTypeName</key><string>Markdown 文档</string>
  <key>CFBundleTypeRole</key><string>Viewer</string>
  <key>LSHandlerRank</key><string>Owner</string>
  <key>LSItemContentTypes</key><array><string>net.daringfireball.markdown</string></array>
</dict></array>
<key>UTImportedTypeDeclarations</key>
<array><dict>
  <key>UTTypeIdentifier</key><string>net.daringfireball.markdown</string>
  <key>UTTypeDescription</key><string>Markdown 文档</string>
  <key>UTTypeConformsTo</key><array><string>public.plain-text</string></array>
  <key>UTTypeTagSpecification</key><dict>
    <key>public.filename-extension</key><array><string>md</string><string>markdown</string></array>
    <key>public.mime-type</key><string>text/markdown</string>
  </dict>
</dict></array>
```

最后执行：

```bash
codesign --force --deep --sign - "$bundle"
ditto -c -k --sequesterRsrc --keepParent "$bundle" "dist/${app_name}.zip"
codesign --verify --deep --strict "$bundle"
```

- [ ] **Step 6: 编写不弹 UI 的烟雾测试脚本**

`scripts/smoke_test.sh` 必须验证：App、二进制、Info.plist、资源 bundle 和 ZIP 均存在；`plutil -lint` 通过；文档角色为 `Viewer`；codesign 校验通过；二进制架构包含 arm64；固定 markdown-it 哈希正确；`Fixtures/sample.md` 在运行 `DocumentLoader` 测试前后的 SHA-256 相同。

```bash
plutil -lint 'dist/可微MD极简阅读器.app/Contents/Info.plist'
codesign --verify --deep --strict 'dist/可微MD极简阅读器.app'
file 'dist/可微MD极简阅读器.app/Contents/MacOS/KeweiMDReader' | grep -q 'arm64'
test "$(shasum -a 256 Sources/KeweiMDReader/Resources/markdown-it.umd.min.js | awk '{print $1}')" = \
  '635972b985228e8af9f0143647c68616b7a3bb09f6946e7e4a52e43dcf5e7be5'
```

- [ ] **Step 7: 编写中文 README**

README 必须包含：系统要求、安装步骤、首次右键打开方法、如何设为 `.md` 默认程序、点击/拖放/双击三种打开方法、字号和打印、完全离线与只读说明、第一版限制、卸载方法。

- [ ] **Step 8: 运行完整验证并手工检查**

Run:

```bash
swift test
scripts/build_app.sh
scripts/smoke_test.sh
open -a "$(pwd)/dist/可微MD极简阅读器.app" "$(pwd)/Fixtures/sample.md"
```

Expected:

- 全部测试 PASS。
- App 显示“可微MD极简阅读器”和排版后的 `sample.md`。
- 表格、任务列表、本地图片、缺失图片占位、远程图片占位和脚本禁用均符合规范。
- 浅色和深色模式、14...28 字号、打印面板均人工验证通过。
- Finder“打开方式”中出现本应用；将其设为默认后双击 `.md` 可打开。
- 关闭网络后再次打开，阅读功能不受影响。
- 打开前后 `Fixtures/sample.md` 的 SHA-256 不变。

- [ ] **Step 9: 提交任务 7**

```bash
git add Sources/KeweiMDReader/Printing Sources/KeweiMDReader/UI/ContentView.swift Fixtures scripts README.md
git commit -m "feat: package 可微MD极简阅读器 app"
```

### Task 8: 最终范围核对和发布候选检查

**Files:**
- Modify only if verification finds a defect in files already listed above.

**Interfaces:**
- Consumes: 完整应用和批准的设计文档。
- Produces: 已验证的本地发布候选、无未提交变更的 Git 状态、最终验收记录。

- [ ] **Step 1: 对照设计文档逐项检查范围**

Run:

```bash
rg -n '编辑|保存|同步|遥测|插件|Mermaid|数学公式|自动更新' Sources Package.swift
```

Expected: 仅允许出现在否定说明、错误提示或测试文字中；生产代码不得出现编辑、保存、同步、遥测或自动更新路径。

- [ ] **Step 2: 搜索网络和文件写入风险**

Run:

```bash
rg -n 'URLSession|dataTask|downloadTask|uploadTask|write\(|FileHandle.*write|removeItem|moveItem|replaceItem' Sources/KeweiMDReader
```

Expected: 无网络 API、源文件写入或删除 API；测试和打包脚本中的临时/构建文件操作不计入运行时应用。

- [ ] **Step 3: 执行干净构建和全套验证**

Run:

```bash
swift package clean
swift test
scripts/build_app.sh
scripts/smoke_test.sh
git status --short
```

Expected: 所有命令退出码为 0；`git status --short` 为空。

- [ ] **Step 4: 记录人工验收结果**

在最终交付说明中逐项记录 Finder 双击、拖放、选择文件、深浅色、字号、打印、离线、本地图片、缺失图片、安全脚本和源文件哈希结果。不得把“测试通过”描述成“已安装为默认程序”，除非实际完成该系统级人工操作。

- [ ] **Step 5: 如有仅验证产生的修复则提交，否则保留干净状态**

```bash
git add -A
git commit -m "fix: resolve release verification findings"
```

Expected: 只有确有修复时才创建此提交；没有修复时跳过提交。
