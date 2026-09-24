import Foundation

@MainActor
final class OpenDocumentBroker: ObservableObject {
    static let shared = OpenDocumentBroker()

    @Published private(set) var pendingURL: URL?

    func enqueue(_ url: URL) {
        pendingURL = url
    }

    func markConsumed(_ url: URL) {
        if pendingURL == url {
            pendingURL = nil
        }
    }
}
