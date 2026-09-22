import SwiftUI
import AppKit

@main
struct OmawriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue

    init() {
        WriterFonts.register()
        _ = WriterDocumentController.sharedWriter
    }

    var body: some Scene {
        Settings {
            SettingsView()
                .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.colorScheme)
        }
        .commands { WriterCommands() }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        AppIconChoice.applySavedSelection()
        NSDocumentController.shared.autosavingDelay = 2
        RecentDocuments.shared.refresh()
        NSApp.activate(ignoringOtherApps: true)

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let hasOpenedFile = NSDocumentController.shared.documents.contains { $0.fileURL != nil }
            if !hasOpenedFile {
                if NSDocumentController.shared.documents.isEmpty {
                    WriterDocumentController.sharedWriter.newDocument()
                }
                QuickOpenManager.shared.show()
            }
        }
    }

    func applicationShouldOpenUntitledFile(_ sender: NSApplication) -> Bool { false }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            QuickOpenManager.shared.show()
            return false
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
