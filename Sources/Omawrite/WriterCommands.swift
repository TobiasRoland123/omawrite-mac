import SwiftUI
import AppKit

struct WriterCommands: Commands {
    @StateObject private var recent = RecentDocuments.shared
    @FocusedValue(\.editorSession) private var editor
    @Environment(\.openWindow) private var openWindow
    @Environment(\.newDocument) private var newDocument
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("showSyntax") private var showSyntax = false
    @AppStorage("fontSize") private var fontSize = 20.0

    var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("New Document") {
                newDocument(MarkdownDocument())
            }
            .appShortcut(KeyboardShortcutConfig.newDocument)

            Button("Quick Open…") {
                QuickOpenManager.shared.show()
            }
            .appShortcut(KeyboardShortcutConfig.quickOpen)

            Button("Open with System Picker…") {
                NSDocumentController.shared.openDocument(nil)
            }
            .appShortcut(KeyboardShortcutConfig.systemOpen)

            Button("Link Folder…") {
                let panel = NSOpenPanel()
                panel.canChooseFiles = false
                panel.canChooseDirectories = true
                panel.allowsMultipleSelection = true
                panel.canCreateDirectories = true
                panel.prompt = "Link Folder"
                panel.message = "Choose folders where you keep your Markdown files and notes."
                panel.begin { response in
                    guard response == .OK else { return }
                    for url in panel.urls {
                        LinkedDirectoriesStore.shared.addDirectory(url: url)
                    }
                }
            }
            .appShortcut(KeyboardShortcutConfig.linkFolder)
        }

        CommandGroup(after: .newItem) {
            Menu("Open Recent") {
                if recent.urls.isEmpty { Text("No Recent Documents") }
                ForEach(recent.urls, id: \.self) { url in
                    Button(url.lastPathComponent) { recent.open(url) }.help(url.path)
                }
                Divider()
                Button("Clear Menu") { recent.clear() }.disabled(recent.urls.isEmpty)
            }
            Divider()
            Button("Close") { NSApp.keyWindow?.performClose(nil) }
                .appShortcut(KeyboardShortcutConfig.close)
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { editor?.save() }
                .appShortcut(KeyboardShortcutConfig.save).disabled(editor == nil)
            Button("Save As…") {
                NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
            }
            .appShortcut(KeyboardShortcutConfig.saveAs)
            .disabled(editor == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") { editor?.printDocument() }
                .appShortcut(KeyboardShortcutConfig.printDocument).disabled(editor == nil)
        }

        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find…") { editor?.find(.showFindInterface) }
                    .appShortcut(KeyboardShortcutConfig.find)
                Button("Find and Replace…") { editor?.find(.showReplaceInterface) }
                    .appShortcut(KeyboardShortcutConfig.findAndReplace)
                Button("Find Next") { editor?.find(.nextMatch) }
                    .appShortcut(KeyboardShortcutConfig.findNext)
                Button("Find Previous") { editor?.find(.previousMatch) }
                    .appShortcut(KeyboardShortcutConfig.findPrevious)
                Button("Use Selection for Find") { editor?.find(.setSearchString) }
                    .appShortcut(KeyboardShortcutConfig.useSelectionForFind)
            }
            .disabled(editor == nil)
        }

        CommandMenu("Format") {
            Group {
                Button("Bold") { editor?.format("**") }.appShortcut(KeyboardShortcutConfig.bold)
                Button("Italic") { editor?.format("*") }.appShortcut(KeyboardShortcutConfig.italic)
                Button("Insert Link") { editor?.insertLink() }.appShortcut(KeyboardShortcutConfig.insertLink)
                Button("Inline Code") { editor?.format("`") }
                    .appShortcut(KeyboardShortcutConfig.inlineCode)
            }
            .disabled(editor == nil)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            Toggle("Focus Mode", isOn: $focusMode).appShortcut(KeyboardShortcutConfig.focusMode)
            Toggle("Show Markdown Syntax", isOn: $showSyntax).appShortcut(KeyboardShortcutConfig.showSyntax)
            Divider()
            Button("Larger Text") { fontSize = min(32, fontSize + 1) }
                .appShortcut(KeyboardShortcutConfig.largerText)
            Button("Smaller Text") { fontSize = max(14, fontSize - 1) }
                .appShortcut(KeyboardShortcutConfig.smallerText)
            Button("Actual Size") { fontSize = 20 }
                .appShortcut(KeyboardShortcutConfig.actualSize)
            Divider()
            Button("Toggle Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                .appShortcut(KeyboardShortcutConfig.fullScreen)
        }

        CommandGroup(replacing: .help) {
            Button("Welcome to Omawrite") {
                do {
                    guard let url = Bundle.module.url(forResource: "Welcome", withExtension: "md") else { return }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    newDocument(MarkdownDocument(text: text))
                } catch { NSApp.presentError(error) }
            }
            Button("Keyboard Shortcuts") { toggleShortcutOverview() }
                .appShortcut(KeyboardShortcutConfig.shortcutOverview)
        }
    }

    private func toggleShortcutOverview() {
        let shortcutWindow = NSApp.windows.first {
            $0.identifier?.rawValue == KeyboardShortcutConfig.windowID
        }

        guard let shortcutWindow else {
            openWindow(id: KeyboardShortcutConfig.windowID)
            return
        }

        if shortcutWindow.isVisible && !shortcutWindow.isMiniaturized {
            shortcutWindow.performClose(nil)
        } else {
            if shortcutWindow.isMiniaturized {
                shortcutWindow.deminiaturize(nil)
            }
            shortcutWindow.makeKeyAndOrderFront(nil)
        }
    }
}
