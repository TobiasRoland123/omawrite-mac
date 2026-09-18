import AppKit

/// Visual attributes only: the underlying string always remains plain Markdown.
enum MarkdownStyler {
    private static let heading = expression("(?m)^(#{1,6}[ \\t]+)(.+)$")
    private static let quote = expression("(?m)^([ \\t]*>+[ \\t]?)(.*)$")
    private static let list = expression("(?m)^([ \\t]*(?:[-+*]|[0-9]+[.)])[ \\t]+(?:\\[[ xX]\\][ \\t]+)?)(.*)$")
    private static let bold = expression("(\\*\\*|__)(?=\\S)(.+?\\S|\\S)\\1")
    private static let italic = expression("(?<![\\w*])\\*(?=\\S)([^*\\n]+)\\*(?!\\*)|(?<![\\w_])_(?=\\S)([^_\\n]+)_(?![\\w_])")
    private static let inlineCode = expression("(`+)([^`\\n]+)\\1")
    private static let link = expression("(?<!!)\\[((?:\\\\.|[^\\]\\n])+)\\]\\(((?:\\\\.|[^)\\n])+)\\)")
    private static let fence = expression("(?m)^[ \\t]{0,3}(`{3,}|~{3,})[^\\n]*$")

    private static func expression(_ pattern: String) -> NSRegularExpression {
        // These are static developer-authored expressions, checked at launch.
        try! NSRegularExpression(pattern: pattern)
    }

    static func apply(to editor: WriterTextView, activeParagraph: NSRange, showSyntax: Bool, focusMode: Bool) {
        guard let storage = editor.textStorage else { return }
        let text = storage.string
        let whole = NSRange(location: 0, length: storage.length)
        let theme = editor.theme
        let size = editor.writerFontSize
        let regular = WriterFonts.font(size: size)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = size * 0.36
        paragraphStyle.paragraphSpacing = 2
        let base: [NSAttributedString.Key: Any] = [
            .font: regular, .foregroundColor: theme.foreground, .paragraphStyle: paragraphStyle
        ]
        editor.typingAttributes = base
        guard whole.length > 0 else { return }

        storage.beginEditing()
        defer { storage.endEditing() }
        storage.setAttributes(base, range: whole)

        var protectedRanges = [NSRange]()
        var openFence: (range: NSRange, marker: String)?
        for match in fence.matches(in: text, range: whole) {
            let marker = (text as NSString).substring(with: match.range(at: 1))
            if let opening = openFence {
                let suffixStart = NSMaxRange(match.range(at: 1))
                let suffix = (text as NSString).substring(with: NSRange(location: suffixStart, length: NSMaxRange(match.range) - suffixStart))
                if marker.first == opening.marker.first, marker.count >= opening.marker.count,
                   suffix.trimmingCharacters(in: .whitespaces).isEmpty {
                    protectedRanges.append(NSRange(location: opening.range.location, length: NSMaxRange(match.range) - opening.range.location))
                    openFence = nil
                }
            } else { openFence = (match.range, marker) }
        }
        if let opening = openFence {
            protectedRanges.append(NSRange(location: opening.range.location, length: whole.length - opening.range.location))
        }
        for range in protectedRanges {
            storage.addAttributes([.backgroundColor: theme.codeBackground, .foregroundColor: theme.muted], range: range)
        }

        func isProtected(_ range: NSRange) -> Bool {
            protectedRanges.contains { NSIntersectionRange($0, range).length > 0 }
        }
        func matches(_ regex: NSRegularExpression, action: (NSTextCheckingResult) -> Void) {
            for match in regex.matches(in: text, range: whole) where !isProtected(match.range) { action(match) }
        }
        func marker(_ range: NSRange, within match: NSRange) {
            guard range.length > 0 else { return }
            let active = NSIntersectionRange(activeParagraph, match).length > 0
            if showSyntax || active {
                storage.addAttribute(.foregroundColor, value: theme.marker, range: range)
            } else {
                storage.addAttributes([.font: WriterFonts.font(size: 0.1), .foregroundColor: theme.background,
                                       .kern: -0.06], range: range)
            }
        }

        matches(inlineCode) { match in
            storage.addAttribute(.backgroundColor, value: theme.codeBackground, range: match.range)
            protectedRanges.append(match.range)
        }
        matches(heading) { match in
            storage.addAttribute(.foregroundColor, value: theme.marker, range: match.range(at: 1))
            storage.addAttribute(.font, value: WriterFonts.font(size: size, bold: true), range: match.range(at: 2))
        }
        matches(quote) { match in
            storage.addAttributes([.foregroundColor: theme.muted, .font: WriterFonts.font(size: size, italic: true)], range: match.range)
            storage.addAttribute(.foregroundColor, value: theme.marker, range: match.range(at: 1))
        }
        matches(list) { match in
            storage.addAttribute(.foregroundColor, value: theme.marker, range: match.range(at: 1))
        }
        matches(bold) { match in
            let content = match.range(at: 2)
            storage.addAttribute(.font, value: WriterFonts.font(size: size, bold: true), range: content)
            marker(match.range(at: 1), within: match.range)
            marker(NSRange(location: NSMaxRange(content), length: match.range(at: 1).length), within: match.range)
        }
        matches(italic) { match in
            let content = match.range(at: match.range(at: 1).location == NSNotFound ? 2 : 1)
            storage.addAttribute(.font, value: WriterFonts.font(size: size, italic: true), range: content)
            marker(NSRange(location: match.range.location, length: 1), within: match.range)
            marker(NSRange(location: NSMaxRange(match.range) - 1, length: 1), within: match.range)
        }
        matches(link) { match in
            let label = match.range(at: 1)
            storage.addAttributes([.foregroundColor: theme.accent, .underlineStyle: NSUnderlineStyle.single.rawValue], range: label)
            marker(NSRange(location: match.range.location, length: 1), within: match.range)
            marker(NSRange(location: NSMaxRange(label), length: NSMaxRange(match.range) - NSMaxRange(label)), within: match.range)
        }
        if focusMode {
            let dim = theme.foreground.blended(withFraction: 0.65, of: theme.background) ?? theme.muted
            let before = NSRange(location: 0, length: min(activeParagraph.location, whole.length))
            let afterStart = min(NSMaxRange(activeParagraph), whole.length)
            let after = NSRange(location: afterStart, length: whole.length - afterStart)
            for range in [before, after] where range.length > 0 {
                storage.addAttribute(.foregroundColor, value: dim, range: range)
            }
        }
    }
}
