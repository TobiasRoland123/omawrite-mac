import Foundation
import Testing
@testable import OmawriteCore

struct TextFileTests {
    @Test func unicodeRoundTripsInAllEncodings() throws {
        for encoding: TextFile.Encoding in [.utf8, .utf8BOM, .utf16LE, .utf16BE] {
            let original = TextFile(text: "# København\nこんにちは 👩🏽‍💻\n", encoding: encoding)
            #expect(try TextFile(data: original.data()) == original)
        }
    }

    @Test func crlfRetainedAfterEditing() throws {
        var file = try TextFile(data: Data("one\r\ntwo\r\n".utf8))
        #expect(file.text == "one\ntwo\n")
        file.text += "three\n"
        #expect(String(decoding: file.data(), as: UTF8.self) == "one\r\ntwo\r\nthree\r\n")
    }

    @Test func invalidAndBinaryDataIsRejectedWithoutLossyDecoding() {
        #expect(throws: TextFileError.self) { try TextFile(data: Data([0xC3, 0x28])) }
        #expect(throws: TextFileError.self) { try TextFile(data: Data([0x61, 0, 0x62])) }
    }

    @Test func emptyDocumentAndTrailingNewlines() throws {
        #expect(try TextFile(data: Data()).text == "")
        let file = TextFile(text: "\n\n")
        #expect(try TextFile(data: file.data()) == file)
    }
}
