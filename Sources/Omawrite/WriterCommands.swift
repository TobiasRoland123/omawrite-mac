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
            .keyboardShortcut("n")

            Button("Quick Open…") {
                QuickOpenManager.shared.show()
            }
            .keyboardShortcut("o")

            Button("Open with System Picker…") {
                NSDocumentController.shared.openDocument(nil)
            }
            .keyboardShortcut("o", modifiers: [.command, .shift])

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
            .keyboardShortcut("d", modifiers: [.command])
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
            Button("Close") { NSApp.keyWindow?.performClose(nil) }.keyboardShortcut("w")
        }

        CommandGroup(replacing: .saveItem) {
            Button("Save") { editor?.save() }
                .keyboardShortcut("s").disabled(editor == nil)
            Button("Save As…") {
                NSApp.sendAction(#selector(NSDocument.saveAs(_:)), to: nil, from: nil)
            }
            .keyboardShortcut("s", modifiers: [.command, .shift])
            .disabled(editor == nil)
        }

        CommandGroup(replacing: .printItem) {
            Button("Print…") { editor?.printDocument() }
                .keyboardShortcut("p").disabled(editor == nil)
        }

        CommandGroup(after: .textEditing) {
            Menu("Find") {
                Button("Find…") { editor?.find(.showFindInterface) }.keyboardShortcut("f")
                Button("Find and Replace…") { editor?.find(.showReplaceInterface) }
                    .keyboardShortcut("f", modifiers: [.command, .option])
                Button("Find Next") { editor?.find(.nextMatch) }.keyboardShortcut("g")
                Button("Find Previous") { editor?.find(.previousMatch) }
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                Button("Use Selection for Find") { editor?.find(.setSearchString) }.keyboardShortcut("e")
            }
            .disabled(editor == nil)
        }

        CommandMenu("Format") {
            Group {
                Button("Bold") { editor?.format("**") }.keyboardShortcut("b")
                Button("Italic") { editor?.format("*") }.keyboardShortcut("i")
                Button("Insert Link") { editor?.insertLink() }.keyboardShortcut("k")
                Button("Inline Code") { editor?.format("`") }
                    .keyboardShortcut("k", modifiers: [.command, .shift])
            }
            .disabled(editor == nil)
        }

        CommandGroup(after: .toolbar) {
            Divider()
            Toggle("Focus Mode", isOn: $focusMode).keyboardShortcut("d", modifiers: [.command, .shift])
            Toggle("Show Markdown Syntax", isOn: $showSyntax).keyboardShortcut("m", modifiers: [.command, .shift])
            Divider()
            Button("Larger Text") { fontSize = min(32, fontSize + 1) }.keyboardShortcut("+")
            Button("Smaller Text") { fontSize = max(14, fontSize - 1) }.keyboardShortcut("-")
            Button("Actual Size") { fontSize = 20 }.keyboardShortcut("0")
            Divider()
            Button("Toggle Full Screen") { NSApp.keyWindow?.toggleFullScreen(nil) }
                .keyboardShortcut("f", modifiers: [.command, .control])
        }

        CommandGroup(replacing: .help) {
            Button("Welcome to Omawrite") {
                do {
                    guard let url = Bundle.module.url(forResource: "Welcome", withExtension: "md") else { return }
                    let text = try String(contentsOf: url, encoding: .utf8)
                    newDocument(MarkdownDocument(text: text))
                } catch { NSApp.presentError(error) }
            }
            Button("Keyboard Shortcuts") { openWindow(id: "shortcuts") }
                .keyboardShortcut("/", modifiers: [.command, .shift])
        }
    }
}
