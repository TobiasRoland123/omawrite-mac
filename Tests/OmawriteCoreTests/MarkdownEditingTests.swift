import Foundation
import Testing
@testable import OmawriteCore

struct MarkdownEditingTests {
    @Test
    func testWrapsAndTogglesMarkers() {
        let wrapped = MarkdownEditing.wrap("hello", selection: NSRange(location: 0, length: 5), marker: "**")
        #expect(wrapped.range == NSRange(location: 0, length: 5))
        #expect(wrapped.replacement == "**hello**")
        #expect(wrapped.selection == NSRange(location: 2, length: 5))

        let unwrapped = MarkdownEditing.wrap("**hello**", selection: NSRange(location: 2, length: 5), marker: "**")
        #expect(unwrapped.range == NSRange(location: 0, length: 9))
        #expect(unwrapped.replacement == "hello")
        #expect(unwrapped.selection == NSRange(location: 0, length: 5))
    }

    @Test
    func testEmptyWrapLeavesCaretBetweenMarkers() {
        let mutation = MarkdownEditing.wrap("abc", selection: NSRange(location: 1, length: 0), marker: "`")
        #expect(mutation.replacement == "``")
        #expect(mutation.selection == NSRange(location: 2, length: 0))
    }

    @Test
    func testWrapHandlesUnicodeAndInvalidRanges() {
        let text = "😀 café"
        let emoji = MarkdownEditing.wrap(text, selection: NSRange(location: 0, length: 2), marker: "*")
        #expect(emoji.replacement == "*😀*")
        #expect(emoji.selection == NSRange(location: 1, length: 2))

        let invalid = MarkdownEditing.wrap(text, selection: NSRange(location: -100, length: 1000), marker: "*")
        #expect(invalid.range == NSRange(location: 0, length: (text as NSString).length))
        #expect(invalid.replacement == "*" + text + "*")
    }

    @Test
    func testInsertLinkEscapesLabelAndDestination() {
        let label = "[read] \\" + "me"
        let mutation = MarkdownEditing.insertLink(label, selection: NSRange(location: 0, length: (label as NSString).length),
                                                  clipboardURL: "https://example.com/a (b)")
        #expect(mutation.replacement == "[\\[read\\] \\\\me](https://example.com/a%20\\(b\\))")
        #expect(mutation.selection.length == 0)

        let placeholder = MarkdownEditing.insertLink("", selection: NSRange(location: 0, length: 0), clipboardURL: "ftp://bad")
        #expect(placeholder.replacement == "[link text](https://)")
        #expect(placeholder.selection == NSRange(location: 1, length: 9))
    }

    @Test
    func testInsertLinkSelectsMissingDestination() {
        let mutation = MarkdownEditing.insertLink("Hi title", selection: NSRange(location: 3, length: 5), clipboardURL: nil)
        #expect(mutation.replacement == "[title](https://)")
        #expect(mutation.selection == NSRange(location: 11, length: 8))
    }

    @Test
    func testInsertLinkRejectsHTTPURLsWithoutAHost() {
        let mutation = MarkdownEditing.insertLink("title", selection: NSRange(location: 0, length: 5),
                                                  clipboardURL: "https:///missing-host")
        #expect(mutation.replacement == "[title](https://)")
        #expect(mutation.selection == NSRange(location: 8, length: 8))
    }

    @Test
    func testContinuesIndentedOrderedAndTaskLists() {
        let ordered = MarkdownEditing.continueList("  9. first", selection: NSRange(location: 10, length: 0))
        #expect(ordered?.replacement == "\n  10. ")
        #expect(ordered?.selection == NSRange(location: 17, length: 0))

        let task = MarkdownEditing.continueList("- [x] done", selection: NSRange(location: 10, length: 0))
        #expect(task?.replacement == "\n- [ ] ")
    }

    @Test
    func testEmptyListExitsAndFencesDoNotContinue() {
        let empty = MarkdownEditing.continueList("- ", selection: NSRange(location: 2, length: 0))
        #expect(empty?.range == NSRange(location: 0, length: 2))
        #expect(empty?.replacement == "\n")

        #expect(MarkdownEditing.continueList("- selected", selection: NSRange(location: 0, length: 2)) == nil)
        #expect(MarkdownEditing.continueList("```\n- code", selection: NSRange(location: 8, length: 0)) == nil)
    }

    @Test
    func testListWithTextAfterCaretIsNotTreatedAsEmpty() {
        let mutation = MarkdownEditing.continueList("- text", selection: NSRange(location: 2, length: 0))
        #expect(mutation?.range == NSRange(location: 2, length: 0))
        #expect(mutation?.replacement == "\n- ")
    }

    @Test
    func testFourSpaceFenceIsNotACommonMarkFence() {
        let text = "    ```\n- code"
        let mutation = MarkdownEditing.continueList(text,
                                                    selection: NSRange(location: (text as NSString).length, length: 0))
        #expect(mutation?.replacement == "\n- ")
    }

    @Test
    func testContinuesUsingCRLF() {
        let text = "- first\r\n- second"
        let mutation = MarkdownEditing.continueList(text, selection: NSRange(location: (text as NSString).length, length: 0))
        #expect(mutation?.replacement == "\r\n- ")
    }

    @Test
    func testCountsUnicodeWordsAndIgnoresStandaloneMarkers() {
        #expect(MarkdownEditing.wordCount("one two-three don't 42") == 4)
        #expect(MarkdownEditing.wordCount("你好 世界 ** * _ [] ()") == 2)
        #expect(MarkdownEditing.wordCount("😀 --- ...") == 0)
    }
}
