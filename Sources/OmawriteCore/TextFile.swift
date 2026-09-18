import Foundation

/// Keeps a document's encoding and line endings intact across edits.
public struct TextFile: Equatable, Sendable {
    public enum Encoding: Sendable { case utf8, utf8BOM, utf16LE, utf16BE }
    public enum LineEnding: String, Sendable { case lf = "\n", crlf = "\r\n", cr = "\r" }

    public var text: String
    public var encoding: Encoding
    public var lineEnding: LineEnding

    public init(text: String = "", encoding: Encoding = .utf8, lineEnding: LineEnding = .lf) {
        self.text = text
        self.encoding = encoding
        self.lineEnding = lineEnding
    }

    public init(data: Data) throws {
        let bytes = Array(data.prefix(3))
        let decoded: String?
        if bytes.starts(with: [0xFF, 0xFE]) {
            encoding = .utf16LE
            decoded = String(data: data.dropFirst(2), encoding: .utf16LittleEndian)
        } else if bytes.starts(with: [0xFE, 0xFF]) {
            encoding = .utf16BE
            decoded = String(data: data.dropFirst(2), encoding: .utf16BigEndian)
        } else if bytes == [0xEF, 0xBB, 0xBF] {
            encoding = .utf8BOM
            decoded = String(data: data.dropFirst(3), encoding: .utf8)
        } else {
            encoding = .utf8
            decoded = String(data: data, encoding: .utf8)
        }
        guard let decoded, !decoded.contains("\0") else { throw TextFileError.unsupportedEncoding }
        if decoded.contains("\r\n") { lineEnding = .crlf }
        else if decoded.contains("\r") { lineEnding = .cr }
        else { lineEnding = .lf }
        text = decoded.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    public func data() -> Data {
        let output = text.replacingOccurrences(of: "\n", with: lineEnding.rawValue)
        switch encoding {
        case .utf8: return Data(output.utf8)
        case .utf8BOM: return Data([0xEF, 0xBB, 0xBF]) + Data(output.utf8)
        case .utf16LE:
            return Data([0xFF, 0xFE]) + (output.data(using: .utf16LittleEndian) ?? Data())
        case .utf16BE:
            return Data([0xFE, 0xFF]) + (output.data(using: .utf16BigEndian) ?? Data())
        }
    }
}

public enum TextFileError: LocalizedError {
    case unsupportedEncoding
    public var errorDescription: String? { "This file isn’t a supported text document." }
    public var recoverySuggestion: String? {
        "Open a Markdown or plain-text file encoded as UTF-8, or UTF-16 with a byte-order mark."
    }
}
