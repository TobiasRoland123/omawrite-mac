import SwiftUI

struct AppShortcut: Identifiable {
    let id: String
    let title: String
    let key: KeyEquivalent
    let modifiers: EventModifiers
    let keyLabel: String

    init(_ id: String, title: String, key: Character,
         modifiers: EventModifiers = .command, keyLabel: String? = nil) {
        self.id = id
        self.title = title
        self.key = KeyEquivalent(key)
        self.modifiers = modifiers
        self.keyLabel = keyLabel ?? String(key).uppercased()
    }

    var keyLabels: [String] {
        var labels: [String] = []
        if modifiers.contains(.control) { labels.append("⌃") }
        if modifiers.contains(.option) { labels.append("⌥") }
        if modifiers.contains(.shift) { labels.append("⇧") }
        if modifiers.contains(.command) { labels.append("⌘") }
        labels.append(keyLabel)
        return labels
    }
}

struct ShortcutSection: Identifiable {
    let id: String
    let title: String
    let shortcuts: [AppShortcut]
}

/// The single source of truth for Omawrite's keyboard shortcuts.
///
/// Add a shortcut here, include it in a section, then apply it to its command
/// with `.appShortcut(KeyboardShortcutConfig.yourShortcut)`.
enum KeyboardShortcutConfig {
    static let windowID = "shortcuts"

    static let newDocument = AppShortcut("new-document", title: "New document", key: "n")
    static let quickOpen = AppShortcut("quick-open", title: "Quick open", key: "o")
    static let systemOpen = AppShortcut("system-open", title: "Open with system picker", key: "o",
                                        modifiers: [.command, .shift])
    static let linkFolder = AppShortcut("link-folder", title: "Link folder", key: "d")
    static let close = AppShortcut("close", title: "Close window", key: "w")
    static let save = AppShortcut("save", title: "Save", key: "s")
    static let saveAs = AppShortcut("save-as", title: "Save as", key: "s",
                                    modifiers: [.command, .shift])
    static let printDocument = AppShortcut("print", title: "Print", key: "p")

    // These commands are supplied by the standard macOS menu system.
    static let undo = AppShortcut("undo", title: "Undo", key: "z")
    static let redo = AppShortcut("redo", title: "Redo", key: "z",
                                  modifiers: [.command, .shift])
    static let find = AppShortcut("find", title: "Find", key: "f")
    static let findAndReplace = AppShortcut("find-replace", title: "Find and replace", key: "f",
                                            modifiers: [.command, .option])
    static let findNext = AppShortcut("find-next", title: "Find next", key: "g")
    static let findPrevious = AppShortcut("find-previous", title: "Find previous", key: "g",
                                          modifiers: [.command, .shift])
    static let useSelectionForFind = AppShortcut("selection-for-find", title: "Use selection for find", key: "e")

    static let bold = AppShortcut("bold", title: "Bold", key: "b")
    static let italic = AppShortcut("italic", title: "Italic", key: "i")
    static let insertLink = AppShortcut("insert-link", title: "Insert link", key: "k")
    static let inlineCode = AppShortcut("inline-code", title: "Inline code", key: "k",
                                        modifiers: [.command, .shift])

    static let focusMode = AppShortcut("focus-mode", title: "Focus mode", key: "d",
                                       modifiers: [.command, .shift])
    static let showSyntax = AppShortcut("show-syntax", title: "Show Markdown syntax", key: "m",
                                       modifiers: [.command, .shift])
    static let largerText = AppShortcut("larger-text", title: "Larger text", key: "+")
    static let smallerText = AppShortcut("smaller-text", title: "Smaller text", key: "-", keyLabel: "−")
    static let actualSize = AppShortcut("actual-size", title: "Actual text size", key: "0")
    static let fullScreen = AppShortcut("full-screen", title: "Toggle full screen", key: "f",
                                       modifiers: [.command, .control])

    static let settings = AppShortcut("settings", title: "Settings", key: ",")
    static let shortcutOverview = AppShortcut("shortcut-overview", title: "Keyboard shortcuts", key: "k",
                                              modifiers: [.command, .option])

    static let sections: [ShortcutSection] = [
        ShortcutSection(id: "file", title: "File", shortcuts: [
            newDocument, quickOpen, systemOpen, linkFolder, close, save, saveAs, printDocument
        ]),
        ShortcutSection(id: "editing", title: "Editing", shortcuts: [
            undo, redo, find, findAndReplace, findNext, findPrevious, useSelectionForFind
        ]),
        ShortcutSection(id: "formatting", title: "Formatting", shortcuts: [
            bold, italic, insertLink, inlineCode
        ]),
        ShortcutSection(id: "view", title: "View", shortcuts: [
            focusMode, showSyntax, largerText, smallerText, actualSize, fullScreen
        ]),
        ShortcutSection(id: "application", title: "Application", shortcuts: [
            settings, shortcutOverview
        ])
    ]
}

extension View {
    func appShortcut(_ shortcut: AppShortcut) -> some View {
        keyboardShortcut(shortcut.key, modifiers: shortcut.modifiers)
    }
}

struct ShortcutsView: View {
    var body: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Keyboard Shortcuts")
                        .font(.system(size: 26, weight: .semibold, design: .serif))
                    Text("Keep your hands on the words.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }

                ForEach(KeyboardShortcutConfig.sections) { section in
                    VStack(alignment: .leading, spacing: 0) {
                        Text(section.title.uppercased())
                            .font(.system(size: 10, weight: .semibold))
                            .tracking(1.5)
                            .foregroundStyle(.secondary)
                            .padding(.bottom, 8)

                        ForEach(section.shortcuts) { shortcut in
                            HStack(spacing: 20) {
                                Text(shortcut.title)
                                    .font(.system(size: 13))
                                Spacer(minLength: 24)
                                HStack(spacing: 4) {
                                    ForEach(Array(shortcut.keyLabels.enumerated()), id: \.offset) { _, label in
                                        Text(label)
                                            .font(.system(size: 12, weight: .medium, design: .rounded))
                                            .frame(minWidth: 22, minHeight: 22)
                                            .background(.quaternary, in: RoundedRectangle(cornerRadius: 5))
                                    }
                                }
                                .accessibilityElement(children: .ignore)
                                .accessibilityLabel(shortcut.keyLabels.joined(separator: " "))
                            }
                            .padding(.vertical, 6)

                            if shortcut.id != section.shortcuts.last?.id {
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(32)
        }
        .frame(minWidth: 440, idealWidth: 520, minHeight: 420, idealHeight: 620)
    }
}
