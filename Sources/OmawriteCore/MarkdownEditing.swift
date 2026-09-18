import Foundation

/// A text replacement and the selection that should be applied after it.
///
/// All offsets are UTF-16 offsets, matching `NSRange` and the text storage
/// APIs used by AppKit's text views.
public struct TextMutation: Equatable {
    public let range: NSRange
    public let replacement: String
    public let selection: NSRange

    public init(range: NSRange, replacement: String, selection: NSRange) {
        self.range = range
        self.replacement = replacement
        self.selection = selection
    }
}

/// Small, editor-independent Markdown editing operations.
public enum MarkdownEditing {
    /// Toggles a pair of `marker` strings around the selection.
    ///
    /// When the selection is inside an existing pair, the pair is removed as
    /// well. An empty selection inserts an empty pair and leaves the caret in
    /// between it.
    public static func wrap(_ text: String, selection: NSRange,
                            marker: String) -> TextMutation {
        let selectedRange = clampedRange(selection, in: text)
        let markerLength = (marker as NSString).length

        guard markerLength > 0 else {
            return TextMutation(range: selectedRange, replacement: selectedText(text, selectedRange),
                                selection: NSRange(location: selectedRange.location,
                                                    length: selectedRange.length))
        }

        let selected = selectedText(text, selectedRange)
        let selectedLength = (selected as NSString).length

        if selectedLength == 0 {
            let textLength = (text as NSString).length
            let caret = selectedRange.location
            if caret >= markerLength, caret <= textLength - markerLength,
               substring(text, NSRange(location: caret - markerLength, length: markerLength)) == marker,
               substring(text, NSRange(location: caret, length: markerLength)) == marker {
                return TextMutation(
                    range: NSRange(location: caret - markerLength, length: markerLength * 2),
                    replacement: "",
                    selection: NSRange(location: caret - markerLength, length: 0))
            }
        }

        // Selecting the markers themselves is also a useful way to toggle
        // them off. Require two complete markers so a short selection such as
        // "**" does not unexpectedly disappear.
        if selectedLength >= markerLength * 2,
           selected.hasPrefix(marker), selected.hasSuffix(marker) {
            let contentLength = selectedLength - markerLength * 2
            let content = (selected as NSString).substring(
                with: NSRange(location: markerLength, length: contentLength))
            return TextMutation(
                range: selectedRange,
                replacement: content,
                selection: NSRange(location: selectedRange.location, length: contentLength))
        }

        // Most text editors pass the content selection (rather than the
        // surrounding markup) to a formatting command. Recognise that shape
        // and remove the adjacent markers when present.
        let textLength = (text as NSString).length
        let end = NSMaxRange(selectedRange)
        if selectedRange.location >= markerLength,
           end <= textLength - markerLength,
           substring(text, NSRange(location: selectedRange.location - markerLength,
                                   length: markerLength)) == marker,
           substring(text, NSRange(location: end, length: markerLength)) == marker {
            let unwrappedRange = NSRange(location: selectedRange.location - markerLength,
                                          length: selectedRange.length + markerLength * 2)
            return TextMutation(range: unwrappedRange, replacement: selected,
                                selection: NSRange(location: unwrappedRange.location,
                                                   length: selectedLength))
        }

        let replacement = marker + selected + marker
        let replacementMarkerLength = (marker as NSString).length
        return TextMutation(
            range: selectedRange,
            replacement: replacement,
            selection: NSRange(location: selectedRange.location + replacementMarkerLength,
                               length: selectedLength))
    }

    /// Inserts a Markdown link. A selected label is retained; otherwise a
    /// placeholder label is inserted and selected for immediate typing.
    public static func insertLink(_ text: String, selection: NSRange,
                                  clipboardURL: String?) -> TextMutation {
        let selectedRange = clampedRange(selection, in: text)
        let selected = selectedText(text, selectedRange)
        let label = selected.isEmpty ? "link text" : selected
        let escapedLabel = escapeLinkLabel(label)
        let acceptedURL = acceptedHTTPURL(clipboardURL)
        let destination = acceptedURL ?? "https://"
        let escapedDestination = escapeLinkDestination(destination)
        let replacement = "[" + escapedLabel + "](" + escapedDestination + ")"
        let replacementLength = (replacement as NSString).length

        if selectedRange.length == 0 {
            let labelLength = (escapedLabel as NSString).length
            return TextMutation(
                range: selectedRange,
                replacement: replacement,
                selection: NSRange(location: selectedRange.location + 1,
                                   length: labelLength))
        }

        if acceptedURL == nil {
            let destinationStart = 1 + (escapedLabel as NSString).length + 2
            let destinationLength = (escapedDestination as NSString).length
            return TextMutation(
                range: selectedRange,
                replacement: replacement,
                selection: NSRange(location: selectedRange.location + destinationStart,
                                   length: destinationLength))
        }

        return TextMutation(range: selectedRange, replacement: replacement,
                            selection: NSRange(location: selectedRange.location + replacementLength,
                                               length: 0))
    }

    /// Returns the edit to make when Return is pressed at a collapsed caret in
    /// a Markdown list. Returns nil for ordinary paragraphs and fenced code.
    public static func continueList(_ text: String, selection: NSRange) -> TextMutation? {
        let selectedRange = clampedRange(selection, in: text)
        guard selectedRange.length == 0 else { return nil }

        let caret = selectedRange.location
        let units = Array(text.utf16)
        let lineStart = startOfLine(units, before: caret)
        if isInsideFence(text, lineStart: lineStart) { return nil }

        let linePrefixRange = NSRange(location: lineStart, length: caret - lineStart)
        let linePrefix = substring(text, linePrefixRange)
        let lineEnd = endOfLine(units, after: caret)
        let lineSuffix = substring(text, NSRange(location: caret, length: lineEnd - caret))

        let unorderedPattern = try! NSRegularExpression(
            pattern: "^([ \\t]*)([-+*])([ \\t]+)(.*)$")
        let orderedPattern = try! NSRegularExpression(
            pattern: "^([ \\t]*)([0-9]+)([.)])([ \\t]+)(.*)$")

        let prefixRange = NSRange(location: 0, length: (linePrefix as NSString).length)
        let unordered = unorderedPattern.firstMatch(in: linePrefix, range: prefixRange)
        let ordered = unordered == nil
            ? orderedPattern.firstMatch(in: linePrefix, range: prefixRange) : nil
        guard let match = unordered ?? ordered else { return nil }

        let isOrdered = ordered != nil
        let indentation = capture(match, index: 1, in: linePrefix)
        let marker: String
        let content: String
        if isOrdered {
            let number = capture(match, index: 2, in: linePrefix)
            let punctuation = capture(match, index: 3, in: linePrefix)
            marker = incrementListNumber(number) + punctuation
            content = capture(match, index: 5, in: linePrefix)
        } else {
            marker = capture(match, index: 2, in: linePrefix)
            content = capture(match, index: 4, in: linePrefix)
        }

        let taskPattern = try! NSRegularExpression(pattern: "^\\[([ xX])\\](?:[ \\t]+|$)(.*)$")
        // Parse the complete current line for emptiness. The caret can be
        // between the marker and the item's text, so looking only at the
        // prefix would incorrectly exit a nonempty item.
        let fullContent = content + lineSuffix
        let fullContentRange = NSRange(location: 0, length: (fullContent as NSString).length)
        let taskMatch = taskPattern.firstMatch(in: fullContent, range: fullContentRange)
        let taskBody = taskMatch.map { capture($0, index: 2, in: fullContent) }
        let isEmpty = taskMatch != nil
            ? (taskBody ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            : fullContent.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let newline = preferredNewline(in: text)
        if isEmpty {
            // Remove the list marker already typed and leave a blank line.
            let replacementLength = (newline as NSString).length
            return TextMutation(
                range: NSRange(location: lineStart, length: caret - lineStart),
                replacement: newline,
                selection: NSRange(location: lineStart + replacementLength, length: 0))
        }

        let continuationTask = taskMatch == nil ? "" : "[ ] "
        let replacement = newline + indentation + marker + " " + continuationTask
        let replacementLength = (replacement as NSString).length
        return TextMutation(
            range: NSRange(location: caret, length: 0),
            replacement: replacement,
            selection: NSRange(location: caret + replacementLength, length: 0))
    }

    /// Counts words made of letters or numbers, allowing an internal apostrophe
    /// or hyphen. Markdown punctuation by itself therefore contributes zero.
    public static func wordCount(_ text: String) -> Int {
        let regex = try! NSRegularExpression(
            pattern: "[\\p{L}\\p{N}]+(?:['’\\-][\\p{L}\\p{N}]+)*")
        let range = NSRange(location: 0, length: (text as NSString).length)
        return regex.numberOfMatches(in: text, range: range)
    }

    private static func selectedText(_ text: String, _ range: NSRange) -> String {
        substring(text, range)
    }

    private static func substring(_ text: String, _ range: NSRange) -> String {
        (text as NSString).substring(with: range)
    }

    private static func clampedRange(_ requested: NSRange, in text: String) -> NSRange {
        let nsText = text as NSString
        let textLength = nsText.length
        let requestedLocation = Int64(requested.location)
        let requestedLength = max(Int64(0), Int64(requested.length))
        let rawEnd: Int64
        if requestedLocation > Int64.max - requestedLength {
            rawEnd = Int64.max
        } else {
            rawEnd = requestedLocation + requestedLength
        }
        let start = Int(max(Int64(0), min(Int64(textLength), requestedLocation)))
        let end = Int(max(Int64(0), min(Int64(textLength), rawEnd)))
        var result = NSRange(location: start, length: max(0, end - start))

        // Never create an NSString slice through a composed character. This
        // also makes malformed ranges that land in the middle of an emoji
        // safe to use.
        if result.length > 0 {
            result = nsText.rangeOfComposedCharacterSequences(for: result)
        } else if result.location < textLength {
            let composed = nsText.rangeOfComposedCharacterSequence(at: result.location)
            if composed.location < result.location {
                result.location = composed.location
            }
        }
        return result
    }

    private static func escapeLinkLabel(_ label: String) -> String {
        label.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "[", with: "\\[")
            .replacingOccurrences(of: "]", with: "\\]")
    }

    private static func escapeLinkDestination(_ destination: String) -> String {
        // Backslash escaping keeps destinations readable while protecting the
        // delimiters that would otherwise terminate a Markdown link.
        destination.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "(", with: "\\(")
            .replacingOccurrences(of: ")", with: "\\)")
            .replacingOccurrences(of: " ", with: "%20")
    }

    private static func acceptedHTTPURL(_ value: String?) -> String? {
        guard let value else { return nil }
        let candidate = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !candidate.contains("\r"), !candidate.contains("\n"),
              let url = URL(string: candidate),
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = url.host, !host.isEmpty else {
            return nil
        }
        return url.absoluteString
    }

    private static func capture(_ match: NSTextCheckingResult, index: Int,
                                in text: String) -> String {
        let range = match.range(at: index)
        guard range.location != NSNotFound else { return "" }
        return substring(text, range)
    }

    private static func startOfLine(_ units: [UInt16], before caret: Int) -> Int {
        guard caret > 0 else { return 0 }
        var index = 0
        var lineStart = 0
        while index < caret {
            if units[index] == 10 { // LF
                lineStart = index + 1
            } else if units[index] == 13 { // CR or CRLF
                if index + 1 < caret, units[index + 1] == 10 { index += 1 }
                lineStart = index + 1
            }
            index += 1
        }
        return lineStart
    }

    private static func preferredNewline(in text: String) -> String {
        if text.range(of: "\r\n") != nil { return "\r\n" }
        if text.range(of: "\r") != nil { return "\r" }
        return "\n"
    }

    private static func isInsideFence(_ text: String, lineStart: Int) -> Bool {
        let units = Array(text.utf16)
        var offset = 0
        var fenceCharacter: UInt16?
        var fenceLength = 0

        while offset < lineStart {
            var end = offset
            while end < units.count, units[end] != 10, units[end] != 13 { end += 1 }
            let line = substring(text, NSRange(location: offset, length: end - offset))
            if let fence = fenceInfo(line) {
                if let activeCharacter = fenceCharacter {
                    if fence.character == activeCharacter, fence.length >= fenceLength,
                       fence.suffixIsWhitespace {
                        fenceCharacter = nil
                        fenceLength = 0
                    }
                } else if fence.length >= 3 {
                    fenceCharacter = fence.character
                    fenceLength = fence.length
                }
            }
            if end >= units.count { break }
            if units[end] == 13, end + 1 < units.count, units[end + 1] == 10 {
                offset = end + 2
            } else {
                offset = end + 1
            }
        }
        return fenceCharacter != nil
    }

    private static func fenceInfo(_ line: String)
        -> (character: UInt16, length: Int, suffixIsWhitespace: Bool)? {
        let units = Array(line.utf16)
        var index = 0
        var spaces = 0
        while index < units.count, spaces < 3,
              units[index] == 32 { index += 1; spaces += 1 }
        guard index < units.count, units[index] == 96 || units[index] == 126 else {
            return nil
        }
        let character = units[index]
        let markerStart = index
        while index < units.count, units[index] == character { index += 1 }
        let markerLength = index - markerStart
        guard markerLength >= 3 else { return nil }
        let suffix = String(decoding: units[index...], as: UTF16.self)
        return (character, markerLength, suffix.trimmingCharacters(in: .whitespaces).isEmpty)
    }

    private static func incrementListNumber(_ value: String) -> String {
        guard let number = UInt64(value), number < UInt64.max else {
            return value
        }
        return String(number + 1)
    }

    private static func endOfLine(_ units: [UInt16], after caret: Int) -> Int {
        var index = caret
        while index < units.count, units[index] != 10, units[index] != 13 { index += 1 }
        return index
    }
}
