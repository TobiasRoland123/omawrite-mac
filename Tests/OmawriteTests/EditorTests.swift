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

    @Test(arguments: ["---", "***", "___", "-----", "* * *", "  _ _ _  ", "-\t-\t-"])
    func dividersPreserveSourceAndRevealTheirSyntax(rule: String) {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        let source = "Before 👩🏽‍💻\n\n\(rule)\n\nAfter"
        editor.string = source
        let divider = (source as NSString).range(of: rule)
        let after = (source as NSString).range(of: "After")
        MarkdownStyler.apply(to: editor, activeParagraph: after, showSyntax: false, focusMode: false)
        #expect(editor.string == source)
        #expect(editor.visibleDividerRanges == [divider])
        #expect((editor.textStorage?.attribute(.foregroundColor, at: divider.location, effectiveRange: nil) as? NSColor) == .clear)

        MarkdownStyler.apply(to: editor, activeParagraph: divider, showSyntax: false, focusMode: false)
        #expect(editor.visibleDividerRanges.isEmpty)
        #expect((editor.textStorage?.attribute(.foregroundColor, at: divider.location, effectiveRange: nil) as? NSColor) == editor.theme.marker)

        MarkdownStyler.apply(to: editor, activeParagraph: after, showSyntax: true, focusMode: false)
        #expect(editor.visibleDividerRanges.isEmpty)
        #expect(editor.string == source)
    }

    @Test(arguments: ["Heading\n---", "```\n---\n```", "~~~\n***", "    ---", "\t___",
                      "<div>\n---\n</div>", "\\---", "- * -", "Text with --- inside"])
    func dividerLikeTextStaysLiteral(source: String) {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: .zero)
        editor.string = source + "\n\nAfter"
        MarkdownStyler.apply(to: editor, activeParagraph: (editor.string as NSString).range(of: "After"),
                             showSyntax: false, focusMode: false)
        #expect(editor.visibleDividerRanges.isEmpty)
        #expect(editor.string == source + "\n\nAfter")
    }

    @Test func consecutiveDividersAndEditsUpdateRendering() {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: .zero)
        editor.string = "Heading\n---\n---\n***\n\nAfter"
        let after = (editor.string as NSString).range(of: "After")
        MarkdownStyler.apply(to: editor, activeParagraph: after, showSyntax: false, focusMode: true)
        #expect(editor.visibleDividerRanges.count == 2)
        #expect(editor.visibleDividerRanges.first?.location == "Heading\n---\n".utf16.count)

        editor.string = "Plain text"
        MarkdownStyler.apply(to: editor, activeParagraph: .init(location: 0, length: 0), showSyntax: false, focusMode: false)
        #expect(editor.visibleDividerRanges.isEmpty)
        editor.string = ""
        MarkdownStyler.apply(to: editor, activeParagraph: .init(location: 0, length: 0), showSyntax: false, focusMode: false)
        #expect(editor.visibleDividerRanges.isEmpty)
    }

    @Test func spacedDividerDoesNotContinueAsAList() {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: .zero)
        editor.isRichText = false
        editor.string = "* * *"
        editor.setSelectedRange(NSRange(location: editor.string.utf16.count, length: 0))
        MarkdownStyler.apply(to: editor, activeParagraph: NSRange(location: 0, length: 5), showSyntax: false, focusMode: false)
        editor.insertNewline(nil)
        #expect(editor.string == "* * *\n")
    }

    @Test func dividerDrawsAcrossTheTextColumn() throws {
        _ = NSApplication.shared
        let editor = WriterTextView(frame: NSRect(x: 0, y: 0, width: 600, height: 240))
        editor.drawsBackground = true
        editor.backgroundColor = editor.theme.background
        editor.textContainerInset = NSSize(width: 20, height: 20)
        editor.string = "Above\n\n---\n\nBelow"
        MarkdownStyler.apply(to: editor, activeParagraph: (editor.string as NSString).range(of: "Below"),
                             showSyntax: false, focusMode: false)
        let bitmap = try #require(editor.bitmapImageRepForCachingDisplay(in: editor.bounds))
        editor.cacheDisplay(in: editor.bounds, to: bitmap)
        let background = try #require(editor.theme.background.usingColorSpace(.deviceRGB))
        let columns = [0.25, 0.5, 0.75].map { Int(Double(bitmap.pixelsWide) * $0) }
        let hasLine = (0..<bitmap.pixelsHigh).contains { y in
            columns.allSatisfy { x in
                guard let color = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.deviceRGB) else { return false }
                return background.redComponent - color.redComponent > 0.1
            }
        }
        #expect(hasLine)
    }
}
