import AppKit
import SwiftUI
import OmawriteCore

@MainActor
final class EditorSession: ObservableObject {
    weak var textView: WriterTextView?
    @Published var selectedWords = 0
    @Published var selectedCharacters = 0
    @Published var showStatistics = false

    func format(_ marker: String) {
        guard let textView, textView.isEditable else { return }
        textView.window?.makeFirstResponder(textView)
        textView.apply(MarkdownEditing.wrap(textView.string, selection: textView.selectedRange(), marker: marker),
                       actionName: marker == "**" ? "Bold" : marker == "*" ? "Italic" : "Inline Code")
    }

    func insertLink() {
        guard let textView, textView.isEditable else { return }
        textView.window?.makeFirstResponder(textView)
        textView.apply(MarkdownEditing.insertLink(textView.string, selection: textView.selectedRange(),
                                                 clipboardURL: NSPasteboard.general.string(forType: .string)),
                       actionName: "Insert Link")
    }

    func find(_ action: NSTextFinder.Action) {
        guard let textView else { return }
        textView.window?.makeFirstResponder(textView)
        let sender = NSMenuItem()
        sender.tag = action.rawValue
        textView.performFindPanelAction(sender)
    }

    func save() {
        textView?.window?.makeKey()
        NSApp.sendAction(#selector(NSDocument.save(_:)), to: nil, from: nil)
    }

    func printDocument() {
        guard let textView else { return }
        let info = NSPrintInfo.shared.copy() as! NSPrintInfo
        info.topMargin = 54
        info.bottomMargin = 54
        info.leftMargin = 54
        info.rightMargin = 54
        info.horizontalPagination = .fit
        info.verticalPagination = .automatic
        info.isVerticallyCentered = false
        let width = info.paperSize.width - info.leftMargin - info.rightMargin
        let printView = NSTextView(frame: NSRect(x: 0, y: 0, width: width, height: 100))
        let contentWidth = width - 2 * (printView.textContainer?.lineFragmentPadding ?? 0)
        printView.textStorage?.setAttributedString(MarkdownPrintRenderer.render(textView.string, contentWidth: contentWidth))
        printView.textContainerInset = NSSize(width: 0, height: 8)
        printView.textContainer?.containerSize = NSSize(width: width, height: CGFloat.greatestFiniteMagnitude)
        printView.layoutManager?.ensureLayout(for: printView.textContainer!)
        let height = printView.layoutManager?.usedRect(for: printView.textContainer!).height ?? 100
        printView.setFrameSize(NSSize(width: width, height: height + 16))
        NSPrintOperation(view: printView, printInfo: info).run()
    }
}

private struct EditorSessionKey: FocusedValueKey { typealias Value = EditorSession }
extension FocusedValues {
    var editorSession: EditorSession? {
        get { self[EditorSessionKey.self] }
        set { self[EditorSessionKey.self] = newValue }
    }
}
