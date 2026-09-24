import AppKit
import SwiftUI
import UniformTypeIdentifiers
import WebKit

struct ContentView: View {
    @EnvironmentObject private var broker: OpenDocumentBroker
    @StateObject private var viewModel = ReaderViewModel()
    @State private var readerWebView: WKWebView?
    @State private var isDropTargeted = false

    var body: some View {
        Group {
            if viewModel.isLoading {
                ProgressView("正在打开…")
            } else if let document = viewModel.document {
                ReaderWebView(
                    document: document,
                    fontSize: viewModel.fontSize,
                    onReady: { readerWebView = $0 }
                )
            } else {
                emptyState
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay {
            if isDropTargeted {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(.tint, style: StrokeStyle(lineWidth: 3, dash: [8]))
                    .padding(12)
                    .allowsHitTesting(false)
            }
        }
        .toolbar {
            ToolbarItemGroup {
                Button(action: chooseFile) {
                    Label("打开文件", systemImage: "folder")
                }
                if let filename = viewModel.document?.url.lastPathComponent {
                    Text(filename)
                        .lineLimit(1)
                }
                Button(action: viewModel.decreaseFontSize) {
                    Label("缩小", systemImage: "textformat.size.smaller")
                }
                .disabled(viewModel.document == nil || viewModel.fontSize <= 14)
                Button(action: viewModel.increaseFontSize) {
                    Label("放大", systemImage: "textformat.size.larger")
                }
                .disabled(viewModel.document == nil || viewModel.fontSize >= 28)
                Button(action: printDocument) {
                    Label("打印", systemImage: "printer")
                }
                .disabled(readerWebView == nil)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted, perform: handleDrop)
        .onReceive(broker.$pendingURL.compactMap { $0 }) { url in
            open(url)
        }
        .alert(
            "无法打开文件",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.clearError() } }
            )
        ) {
            Button("好", role: .cancel) { viewModel.clearError() }
        } message: {
            Text(viewModel.errorMessage ?? ReaderError.unreadableFile.userMessage)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "doc.richtext")
                .font(.system(size: 44))
                .foregroundStyle(.secondary)
            Text("打开或拖入一个 Markdown 文件")
                .font(.title3)
            Button("打开文件", action: chooseFile)
                .buttonStyle(.borderedProminent)
        }
    }

    private func chooseFile() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = ["md", "markdown"].compactMap {
            UTType(filenameExtension: $0)
        }
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            open(url)
        }
    }

    private func printDocument() {
        guard let readerWebView else { return }
        PrintCoordinator().print(readerWebView)
    }

    private func open(_ url: URL) {
        readerWebView = nil
        Task {
            await viewModel.open(url)
            broker.markConsumed(url)
        }
    }

    private func handleDrop(_ providers: [NSItemProvider]) -> Bool {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier)
        }) else {
            return false
        }

        provider.loadDataRepresentation(forTypeIdentifier: UTType.fileURL.identifier) { data, _ in
            guard let data,
                  let text = String(data: data, encoding: .utf8),
                  let url = URL(string: text.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                return
            }
            Task { @MainActor in open(url) }
        }
        return true
    }
}
