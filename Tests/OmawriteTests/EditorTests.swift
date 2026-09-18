import AppKit
import Testing
@testable import Omawrite

@MainActor
struct EditorTests {
    @Test func stylingPreservesSourceAndRevealsActiveParagraph() {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let source = "**Hello** 👩🏽‍💻\n\nThe next paragraph."
        editor.string = source
        let next = (source as NSString).paragraphRange(for: NSRange(location: (source as NSString).length, length: 0))
        MarkdownStyler.apply(to: editor, activeParagraph: next, showSyntax: false, focusMode: false)
        #expect(editor.string == source)
        let hidden = editor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(hidden?.pointSize == 0.1)

        let first = (source as NSString).paragraphRange(for: NSRange(location: 0, length: 0))
        MarkdownStyler.apply(to: editor, activeParagraph: first, showSyntax: false, focusMode: false)
        let visible = editor.textStorage?.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(visible?.pointSize == 20)
        #expect(editor.string == source)
    }

    @Test func codeFencesKeepLiteralMarkdownVisible() {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: .zero)
        editor.string = "```\n**literal**\n```\n\nOther paragraph"
        let range = (editor.string as NSString).range(of: "**literal**")
        MarkdownStyler.apply(to: editor, activeParagraph: NSRange(location: editor.string.utf16.count, length: 0),
                             showSyntax: false, focusMode: false)
        let font = editor.textStorage?.attribute(.font, at: range.location, effectiveRange: nil) as? NSFont
        #expect(font?.pointSize == 20)
    }

    @Test func printRendersMarkdownAndRetainsParagraphBoundaries() {
        let result = MarkdownPrintRenderer.render("# Title\n\nHello **world**.\n\n- One\n- Two")
        #expect(result.string == "Title\nHello world.\n•\tOne\n•\tTwo")
        let titleFont = result.attribute(.font, at: 0, effectiveRange: nil) as? NSFont
        #expect(titleFont?.pointSize == 22)
        let word = (result.string as NSString).range(of: "world")
        let boldFont = result.attribute(.font, at: word.location, effectiveRange: nil) as? NSFont
        #expect(boldFont.map { NSFontManager.shared.traits(of: $0).contains(.boldFontMask) } == true)
    }
}
