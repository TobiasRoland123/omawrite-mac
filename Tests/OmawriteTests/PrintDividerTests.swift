import AppKit
import Testing
@testable import Omawrite

struct PrintDividerTests {
    @Test func horizontalRuleUsesPrintableWidth() {
        let result = MarkdownPrintRenderer.render("Before\n\n---\n\nAfter", contentWidth: 360)

        #expect(result.string.contains("Before"))
        #expect(result.string.contains("After"))
        let dividerLocation = (result.string as NSString).range(of: "\u{FFFC}")
        #expect(dividerLocation.location != NSNotFound)
        guard dividerLocation.location != NSNotFound else { return }
        let attachment = result.attribute(.attachment, at: dividerLocation.location, effectiveRange: nil) as? NSTextAttachment
        #expect(attachment?.image?.size.width == 360)
        #expect(attachment?.image?.size.height == 1)
    }

    @Test func consecutiveHorizontalRulesRemainSeparated() {
        let result = MarkdownPrintRenderer.render("---\n\n---", contentWidth: 240)

        let dividerCount = result.string.utf16.filter { $0 == 0xFFFC }.count
        #expect(dividerCount == 2)
        #expect(result.string == "\u{FFFC}\n\u{FFFC}")
    }

    @Test func setextHeadingAndFencedCodeAreNotDividers() {
        let result = MarkdownPrintRenderer.render("Title\n---\n\n```\n---\n```", contentWidth: 240)

        #expect(result.string == "Title\n---\n")
        #expect(result.string.utf16.filter { $0 == 0xFFFC }.isEmpty)
    }
}
