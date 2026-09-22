import SwiftUI
import OmawriteCore

struct EditorView: View {
    @Binding var document: MarkdownDocument
    let fileURL: URL?
    let isEditable: Bool
    @ObservedObject var session: EditorSession
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("fontSize") private var fontSize = 20.0
    @AppStorage("showSyntax") private var showSyntax = false
    @AppStorage("focusMode") private var focusMode = false
    @AppStorage("spellcheck") private var spellcheck = true

    private var theme: PaperTheme { PaperTheme(dark: colorScheme == .dark) }
    private var words: Int { MarkdownEditing.wordCount(document.text) }

    var body: some View {
        VStack(spacing: 0) {
            MarkdownEditor(text: $document.text, session: session, theme: theme,
                           fontSize: fontSize, showSyntax: showSyntax, focusMode: focusMode,
                           spellcheck: spellcheck, isEditable: isEditable)

            HStack(spacing: 18) {
                footerButton("Save", symbol: "square.and.arrow.down", action: session.save)
                footerButton("Quick Open (⌘O)", symbol: "folder") {
                    QuickOpenManager.shared.show()
                }
                Text(isEditable ? (fileURL == nil ? "DRAFT" : fileURL!.lastPathComponent) : "READ ONLY")
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .tracking(fileURL == nil ? 1.8 : 0)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .accessibilityLabel(fileURL == nil ? "Unsaved draft" : fileURL!.lastPathComponent)

                Spacer(minLength: 20)

                footerButton(focusMode ? "Turn Off Focus Mode" : "Focus Mode", symbol: "viewfinder") {
                    focusMode.toggle()
                }
                .foregroundStyle(Color(nsColor: focusMode ? theme.accent : theme.muted))

                Button {
                    session.showStatistics.toggle()
                } label: {
                    Text(session.selectedWords > 0
                         ? "\(session.selectedWords) of \(words) words"
                         : "\(words) \(words == 1 ? "word" : "words")")
                        .font(.system(size: 11, design: .monospaced))
                        .monospacedDigit()
                }
                .buttonStyle(.plain)
                .help("Document statistics")
                .popover(isPresented: $session.showStatistics, arrowEdge: .top) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("THE DOCUMENT").font(.system(size: 10, weight: .semibold)).tracking(2)
                        stat("Words", value: "\(words)")
                        stat("Characters", value: "\(document.text.count)")
                        stat("Reading time", value: words == 0 ? "—" : "\(max(1, (words + 199) / 200)) min")
                    }
                    .padding(22)
                    .frame(width: 240)
                }
            }
            .foregroundStyle(Color(nsColor: theme.muted))
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .padding(.bottom, 18)
        }
        .background(Color(nsColor: theme.background))
        .frame(minWidth: 540, minHeight: 380)
        .focusedSceneValue(\.editorSession, session)
        .onChange(of: fileURL, initial: true) { _, url in
            if let url { RecentDocuments.shared.remember(url) }
        }
    }

    private func footerButton(_ title: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol).font(.system(size: 13, weight: .regular))
                .frame(width: 18, height: 20).contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .help(title)
        .accessibilityLabel(title)
    }

    private func stat(_ title: String, value: String) -> some View {
        HStack { Text(title).foregroundStyle(.secondary); Spacer(); Text(value).monospacedDigit() }
            .font(.system(size: 12))
    }
}
