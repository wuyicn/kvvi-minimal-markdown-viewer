import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        guard let url = urls.first else { return }
        OpenDocumentBroker.shared.enqueue(url)
    }

    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        OpenDocumentBroker.shared.enqueue(URL(fileURLWithPath: filename))
        sender.reply(toOpenOrPrint: .success)
    }
}
