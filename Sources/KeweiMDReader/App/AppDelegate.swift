import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func application(_ sender: NSApplication, openFiles filenames: [String]) {
        guard let filename = filenames.first else {
            sender.reply(toOpenOrPrint: .failure)
            return
        }
        OpenDocumentBroker.shared.enqueue(URL(fileURLWithPath: filename))
        sender.reply(toOpenOrPrint: .success)
    }
}

