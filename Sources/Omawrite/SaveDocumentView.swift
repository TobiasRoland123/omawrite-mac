import AppKit
import SwiftUI

struct SaveDocumentView: View {
    @ObservedObject var viewModel: SaveDocumentViewModel
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue
    @FocusState private var focusedField: Field?
    private enum Field { case name, folder }

    private var theme: PaperTheme {
        let dark = AppearanceChoice(rawValue: appearance)?.colorScheme.map { $0 == .dark } ?? (colorScheme == .dark)
        return PaperTheme(dark: dark)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "doc.text")
                    .font(.system(size: 24, weight: .light))
                    .foregroundStyle(Color(nsColor: theme.accent))
                    .padding(.top, 3)
                VStack(alignment: .leading, spacing: 6) {
                    Text(viewModel.isClosing ? "Keep this draft?" : "Save your words.")
                        .font(.system(size: 24, weight: .medium, design: .serif))
                    Text(viewModel.isClosing ? "Save it before closing, or discard this draft." : "Choose a name and a home for your document.")
                        .font(.system(size: 12))
                        .foregroundStyle(Color(nsColor: theme.muted))
                }
            }

            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("FILE NAME", hint: "Markdown or plain text")
                TextField("Untitled.md", text: $viewModel.fileName)
                    .focused($focusedField, equals: .name)
                    .accessibilityLabel("File name")
                    .accessibilityIdentifier("save-file-name")
                    .modifier(SaveFieldStyle(theme: theme, focused: focusedField == .name))
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    fieldLabel("FOLDER", hint: nil)
                    Spacer()
                    Button { focusedField = .folder } label: {
                        Text("⇧⌘G").font(.system(size: 11, design: .monospaced))
                    }
                    .buttonStyle(.plain)
                    .keyboardShortcut("g", modifiers: [.command, .shift])
                    .help("Edit folder path")
                    .accessibilityLabel("Edit folder path")
                }
                TextField("~/Documents", text: $viewModel.directoryPath)
                    .focused($focusedField, equals: .folder)
                    .accessibilityLabel("Folder path")
                    .accessibilityIdentifier("save-folder-path")
                    .modifier(SaveFieldStyle(theme: theme, focused: focusedField == .folder))

                HStack(spacing: 8) {
                    Menu {
                        ForEach(viewModel.linkedDirectories) { directory in
                            Button(directory.displayName) { viewModel.chooseDirectory(directory.url) }
                                .help(directory.path)
                        }
                        if !viewModel.linkedDirectories.isEmpty { Divider() }
                        Button("Home") { viewModel.chooseDirectory(FileManager.default.homeDirectoryForCurrentUser) }
                        Button("Documents") { chooseStandardDirectory(.documentDirectory) }
                        Button("Desktop") { chooseStandardDirectory(.desktopDirectory) }
                    } label: {
                        Label("Locations", systemImage: "folder")
                    }
                    .fixedSize()
                    .accessibilityLabel("Choose a save location")
                    Spacer()
                    Text("Type a path · .md added if omitted")
                        .font(.system(size: 10.5))
                        .foregroundStyle(Color(nsColor: theme.muted))
                }
            }

            VStack(alignment: .leading, spacing: 5) {
                if let error = viewModel.errorMessage {
                    Label(error, systemImage: "exclamationmark.circle")
                        .foregroundStyle(.red)
                } else if let url = viewModel.replacementURL {
                    Label("“\(url.lastPathComponent)” already exists. Replace its contents?", systemImage: "exclamationmark.triangle")
                        .foregroundStyle(Color(nsColor: theme.accent))
                } else {
                    Text("Tab between fields · Return to save · Esc to cancel")
                        .foregroundStyle(Color(nsColor: theme.muted))
                }
            }
            .font(.system(size: 12))
            .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)

            Divider().opacity(0.3)

            HStack(spacing: 12) {
                if viewModel.isClosing {
                    Button("Discard Draft") { viewModel.onDiscard?() }
                        .keyboardShortcut("d", modifiers: .command)
                        .foregroundStyle(.red)
                        .help("Discard draft (⌘D)")
                }
                Spacer()
                Button("Cancel") { viewModel.onCancel?() }
                    .keyboardShortcut(.cancelAction)
                Button(viewModel.isSaving ? "Saving…" : viewModel.replacementURL == nil ? "Save" : "Replace") {
                    viewModel.submit()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
                .tint(Color(nsColor: theme.accent))
            }
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 600)
        .foregroundStyle(Color(nsColor: theme.foreground))
        .background(Color(nsColor: theme.background))
        .disabled(viewModel.isSaving)
        .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.colorScheme)
        .onAppear { focusedField = .name }
    }

    private func fieldLabel(_ title: String, hint: String?) -> some View {
        HStack {
            Text(title).font(.system(size: 10, weight: .semibold)).tracking(1.5)
            if let hint {
                Spacer()
                Text(hint).font(.system(size: 11))
            }
        }
        .foregroundStyle(Color(nsColor: theme.muted))
    }

    private func chooseStandardDirectory(_ directory: FileManager.SearchPathDirectory) {
        if let url = FileManager.default.urls(for: directory, in: .userDomainMask).first {
            viewModel.chooseDirectory(url)
        }
    }
}

private struct SaveFieldStyle: ViewModifier {
    let theme: PaperTheme
    let focused: Bool

    func body(content: Content) -> some View {
        content
            .textFieldStyle(.plain)
            .font(Font(WriterFonts.font(size: 14)))
            .padding(.horizontal, 12)
            .padding(.vertical, 11)
            .background(Color(nsColor: theme.codeBackground), in: RoundedRectangle(cornerRadius: 7))
            .overlay(RoundedRectangle(cornerRadius: 7)
                .stroke(Color(nsColor: focused ? theme.accent : theme.marker).opacity(focused ? 0.8 : 0.3), lineWidth: 1))
    }
}
