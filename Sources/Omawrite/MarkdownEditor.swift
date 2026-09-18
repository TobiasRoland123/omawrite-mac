import AppKit
import SwiftUI
import OmawriteCore

struct MarkdownEditor: NSViewRepresentable {
    @Binding var text: String
    let session: EditorSession
    let theme: PaperTheme
    let fontSize: Double
    let showSyntax: Bool
    let focusMode: Bool
    let spellcheck: Bool
    let isEditable: Bool

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeNSView(context: Context) -> WriterScrollView {
        let scroll = WriterScrollView()
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.findBarPosition = .aboveContent

        let storage = NSTextStorage()
        let layout = NSLayoutManager()
        let container = NSTextContainer(containerSize: NSSize(width: 680, height: CGFloat.greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let editor = WriterTextView(frame: .zero, textContainer: container)
        editor.isRichText = false
        editor.importsGraphics = false
        editor.allowsUndo = true
        editor.isVerticallyResizable = true
        editor.isHorizontallyResizable = false
        editor.autoresizingMask = [.width]
        editor.minSize = .zero
        editor.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        editor.usesFindBar = true
        editor.isIncrementalSearchingEnabled = true
        editor.isAutomaticQuoteSubstitutionEnabled = false
        editor.isAutomaticDashSubstitutionEnabled = false
        editor.isAutomaticTextReplacementEnabled = false
        editor.isAutomaticSpellingCorrectionEnabled = false
        editor.isAutomaticLinkDetectionEnabled = false
        editor.isAutomaticDataDetectionEnabled = false
        editor.smartInsertDeleteEnabled = false
        editor.drawsBackground = false
        editor.setAccessibilityLabel("Markdown editor")
        editor.setAccessibilityIdentifier("markdown-editor")
        editor.setAccessibilityHelp("Write Markdown. Command B for bold, Command I for italic, Command K for a link.")
        editor.delegate = context.coordinator
        editor.string = text
        editor.setSelectedRange(NSRange(location: 0, length: 0))
        scroll.documentView = editor
        context.coordinator.editor = editor
        session.textView = editor
        configure(editor, scroll: scroll, coordinator: context.coordinator)
        DispatchQueue.main.async {
            editor.window?.makeFirstResponder(editor)
            editor.scrollRangeToVisible(NSRange(location: 0, length: 0))
        }
        return scroll
    }

    func updateNSView(_ scroll: WriterScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.parent = self
        guard let editor = scroll.documentView as? WriterTextView else { return }
        // Attribute styling never changes the document binding. Only user text
        // edits do; external document reloads come back through this path.
        if editor.string != text, !editor.hasMarkedText() {
            let selection = editor.selectedRange()
            editor.string = text
            let length = (text as NSString).length
            editor.setSelectedRange(NSRange(location: min(selection.location, length), length: 0))
            coordinator.lastStyledText = nil
        }
        configure(editor, scroll: scroll, coordinator: coordinator)
    }

    private func configure(_ editor: WriterTextView, scroll: WriterScrollView, coordinator: Coordinator) {
        let size = min(32, max(14, fontSize))
        let settings = StyleSettings(dark: theme.dark, fontSize: size, showSyntax: showSyntax, focus: focusMode)
        editor.theme = theme
        editor.writerFontSize = size
        editor.insertionPointColor = theme.accent
        editor.selectedTextAttributes = [.backgroundColor: theme.selection, .foregroundColor: theme.foreground]
        editor.isContinuousSpellCheckingEnabled = spellcheck
        editor.isEditable = isEditable
        scroll.backgroundColor = theme.background
        scroll.scrollerKnobStyle = theme.dark ? .light : .dark
        editor.window?.backgroundColor = theme.background
        scroll.updateEditorInsets()
        if coordinator.settings != settings {
            coordinator.settings = settings
            coordinator.lastStyledText = nil
        }
        coordinator.restyle()
    }

    struct StyleSettings: Equatable {
        var dark: Bool
        var fontSize: Double
        var showSyntax: Bool
        var focus: Bool
    }

    final class Coordinator: NSObject, NSTextViewDelegate {
        var parent: MarkdownEditor
        weak var editor: WriterTextView?
        var settings: StyleSettings?
        var lastStyledText: String?
        var lastParagraph = NSRange(location: NSNotFound, length: 0)
        var isStyling = false

        init(_ parent: MarkdownEditor) { self.parent = parent }

        func textDidChange(_ notification: Notification) {
            guard let editor, !isStyling else { return }
            parent.text = editor.string
            restyle()
            updateSelection()
            editor.needsDisplay = true
        }

        func textViewDidChangeSelection(_ notification: Notification) {
            guard !isStyling else { return }
            restyle()
            updateSelection()
        }

        private func updateSelection() {
            guard let editor else { return }
            let source = editor.string as NSString
            let range = editor.selectedRange()
            guard range.location <= source.length, range.length <= source.length - range.location else { return }
            let selection = source.substring(with: range)
            let words = MarkdownEditing.wordCount(selection)
            // Selection callbacks may run during a SwiftUI update.
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.parent.session.selectedWords = words
                self.parent.session.selectedCharacters = selection.count
            }
        }

        func restyle() {
            guard let editor, let settings, !isStyling, !editor.hasMarkedText() else { return }
            let source = editor.string as NSString
            let selection = editor.selectedRange()
            let position = min(selection.location, source.length)
            let paragraph = source.paragraphRange(for: NSRange(location: position, length: 0))
            guard lastStyledText != editor.string || lastParagraph != paragraph else { return }
            isStyling = true
            defer { isStyling = false }
            MarkdownStyler.apply(to: editor, activeParagraph: paragraph,
                                 showSyntax: settings.showSyntax, focusMode: settings.focus)
            lastStyledText = editor.string
            lastParagraph = paragraph
        }
    }
}

final class WriterScrollView: NSScrollView {
    override func tile() {
        super.tile()
        updateEditorInsets()
    }

    func updateEditorInsets() {
        guard let editor = documentView as? WriterTextView else { return }
        let width = contentSize.width
        let characterWidth = ("m" as NSString).size(withAttributes: [.font: WriterFonts.font(size: editor.writerFontSize)]).width
        let columnWidth = min(characterWidth * 65, max(240, width - 72))
        let inset = NSSize(width: max(28, (width - columnWidth) / 2), height: 52)
        if abs(editor.textContainerInset.width - inset.width) > 0.5 || editor.textContainerInset.height != inset.height {
            editor.textContainerInset = inset
        }
        if abs(editor.frame.width - width) > 0.5 {
            editor.setFrameSize(NSSize(width: width, height: max(editor.frame.height, contentSize.height)))
        }
    }
}

final class WriterTextView: NSTextView {
    var theme = PaperTheme(dark: false)
    var writerFontSize: CGFloat = 20

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        window?.titlebarAppearsTransparent = true
        window?.backgroundColor = theme.background
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        if string.isEmpty {
            ("# Start writing" as NSString).draw(at: textContainerOrigin,
                withAttributes: [.font: WriterFonts.font(size: writerFontSize),
                                 .foregroundColor: theme.marker])
        }
    }

    func apply(_ mutation: TextMutation, actionName: String) {
        guard isEditable, shouldChangeText(in: mutation.range, replacementString: mutation.replacement) else { return }
        breakUndoCoalescing()
        replaceCharacters(in: mutation.range, with: mutation.replacement)
        didChangeText()
        setSelectedRange(mutation.selection)
        scrollRangeToVisible(mutation.selection)
        undoManager?.setActionName(actionName)
        breakUndoCoalescing()
    }

    override func insertNewline(_ sender: Any?) {
        if !hasMarkedText(), let mutation = MarkdownEditing.continueList(string, selection: selectedRange()) {
            apply(mutation, actionName: "Continue List")
        } else {
            super.insertNewline(sender)
        }
    }

    override func paste(_ sender: Any?) {
        guard let pasted = NSPasteboard.general.string(forType: .string) else {
            super.pasteAsPlainText(sender)
            return
        }
        let selection = selectedRange()
        if selection.length > 0,
           let url = URL(string: pasted.trimmingCharacters(in: .whitespacesAndNewlines)),
           ["https", "http"].contains(url.scheme?.lowercased() ?? ""), url.host != nil {
            apply(MarkdownEditing.insertLink(string, selection: selection, clipboardURL: url.absoluteString),
                  actionName: "Paste Link")
        } else {
            let normalized = pasted.replacingOccurrences(of: "\r\n", with: "\n")
                .replacingOccurrences(of: "\r", with: "\n")
            insertText(normalized, replacementRange: selection)
        }
    }

    override func cancelOperation(_ sender: Any?) {
        if enclosingScrollView?.isFindBarVisible == true {
            let item = NSMenuItem()
            item.tag = NSTextFinder.Action.hideFindInterface.rawValue
            performFindPanelAction(item)
            window?.makeFirstResponder(self)
        } else {
            super.cancelOperation(sender)
        }
    }
}
