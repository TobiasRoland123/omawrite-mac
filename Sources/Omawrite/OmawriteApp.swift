import SwiftUI
import AppKit

@main
struct OmawriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue

    init() {
        WriterFonts.register()
    }

    var body: some Scene {
        DocumentGroup(newDocument: MarkdownDocument()) { configuration in
            EditorView(document: configuration.$document,
                       fileURL: configuration.fileURL,
                       isEditable: configuration.isEditable)
                .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.colorScheme)
        }
        .defaultSize(width: 1080, height: 780)
        .windowToolbarStyle(.unifiedCompact)
        .commands { WriterCommands() }

        Settings {
            SettingsView()
                .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.colorScheme)
        }

        Window("Keyboard Shortcuts", id: KeyboardShortcutConfig.windowID) {
            ShortcutsView()
        }
        .defaultSize(width: 520, height: 620)
        .defaultPosition(.center)
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
                QuickOpenManager.shared.show()
            }
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            QuickOpenManager.shared.show()
            return false
        }
        return true
    }

    func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool { true }
}
