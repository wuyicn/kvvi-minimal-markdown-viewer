import SwiftUI

@main
struct KeweiMDReaderApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var broker = OpenDocumentBroker.shared

    var body: some Scene {
        WindowGroup("可微MD极简阅读器") {
            ContentView()
                .environmentObject(broker)
                .frame(minWidth: 720, minHeight: 520)
        }
    }
}
