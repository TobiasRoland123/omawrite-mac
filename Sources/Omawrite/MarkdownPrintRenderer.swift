import AppKit

enum MarkdownPrintRenderer {
    /// Uses Foundation's Markdown parser so print/PDF output contains formatted
    /// prose, while the file on disk remains untouched Markdown.
    static func render(_ source: String, contentWidth: CGFloat = 500) -> NSAttributedString {
        guard let parsed = try? AttributedString(markdown: source) else {
            return NSAttributedString(string: source, attributes: [.font: WriterFonts.font(size: 12)])
        }
        let result = NSMutableAttributedString()
        var previousBlock: Int?
        for run in parsed.runs {
            let components = run.presentationIntent?.components ?? []
            let block = components.first?.identity
            let newBlock = block != previousBlock
            var size: CGFloat = 12
            var isHeading = false
            var isCodeBlock = false
            var isQuote = false
            var isThematicBreak = false
            var listOrdinal: Int?
            var ordered = false
            for component in components {
                switch component.kind {
                case .header(let level):
                    size = level == 1 ? 22 : level == 2 ? 17 : 14
                    isHeading = true
                case .codeBlock: isCodeBlock = true
                case .blockQuote: isQuote = true
                case .listItem(let ordinal): listOrdinal = ordinal
                case .orderedList: ordered = true
                case .thematicBreak: isThematicBreak = true
                default: break
                }
            }
            let inline = run.inlinePresentationIntent ?? []
            let paragraph = NSMutableParagraphStyle()
            paragraph.lineSpacing = 4
            paragraph.paragraphSpacing = listOrdinal == nil || isThematicBreak ? 12 : 4
            if listOrdinal != nil && !isThematicBreak {
                paragraph.headIndent = 22
                paragraph.tabStops = [NSTextTab(textAlignment: .left, location: 22)]
            } else if isQuote && !isThematicBreak {
                paragraph.firstLineHeadIndent = 18
                paragraph.headIndent = 18
            }
            var attributes: [NSAttributedString.Key: Any] = [
                .font: WriterFonts.font(size: size, bold: isHeading || inline.contains(.stronglyEmphasized),
                                       italic: isQuote || inline.contains(.emphasized)),
                .foregroundColor: isQuote ? NSColor.darkGray : NSColor.black,
                .paragraphStyle: paragraph
            ]
            if isCodeBlock || inline.contains(.code) {
                attributes[.backgroundColor] = NSColor(white: 0.95, alpha: 1)
            }
            if inline.contains(.strikethrough) { attributes[.strikethroughStyle] = NSUnderlineStyle.single.rawValue }
            if let link = run.link {
                attributes[.link] = link
                attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
            }
            if newBlock {
                if result.length > 0 { result.append(NSAttributedString(string: "\n", attributes: attributes)) }
                if let ordinal = listOrdinal, !isThematicBreak {
                    result.append(NSAttributedString(string: ordered ? "\(ordinal).\t" : "•\t", attributes: attributes))
                }
            }
            if isThematicBreak {
                let width = max(contentWidth, 1)
                let image = NSImage(size: NSSize(width: width, height: 1), flipped: false) { rect in
                    NSColor(white: 0.65, alpha: 1).setFill()
                    rect.fill()
                    return true
                }
                let attachment = NSTextAttachment()
                attachment.image = image
                attachment.bounds = NSRect(x: 0, y: 5, width: width, height: 1)
                let divider = NSMutableAttributedString(attachment: attachment)
                divider.addAttributes(attributes, range: NSRange(location: 0, length: divider.length))
                result.append(divider)
            } else {
                result.append(NSAttributedString(string: String(parsed[run.range].characters), attributes: attributes))
            }
            previousBlock = block
        }
        return result
    }
}
