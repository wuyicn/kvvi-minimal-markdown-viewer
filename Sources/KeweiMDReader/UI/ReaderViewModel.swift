import Foundation

@MainActor
final class ReaderViewModel: ObservableObject {
    @Published private(set) var document: LoadedDocument?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isLoading = false
    @Published private(set) var fontSize = 17

    private let loader: DocumentLoader

    init(loader: DocumentLoader = DocumentLoader()) {
        self.loader = loader
    }

    func open(_ url: URL) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        let loader = self.loader
        do {
            document = try await Task.detached {
                try loader.load(from: url)
            }.value
        } catch let error as ReaderError {
            errorMessage = error.userMessage
        } catch {
            errorMessage = ReaderError.unreadableFile.userMessage
        }
    }

    func increaseFontSize() {
        fontSize = min(fontSize + 1, 28)
    }

    func decreaseFontSize() {
        fontSize = max(fontSize - 1, 14)
    }

    func clearError() {
        errorMessage = nil
    }
}
