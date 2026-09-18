import SwiftUI
import UniformTypeIdentifiers
import OmawriteCore

extension UTType {
    static let markdown = UTType(importedAs: "net.daringfireball.markdown", conformingTo: .plainText)
}

struct MarkdownDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.markdown, .plainText] }
    static var writableContentTypes: [UTType] { [.markdown, .plainText] }

    var file: TextFile
    var text: String {
        get { file.text }
        set { file.text = newValue }
    }

    init(text: String = "") { file = TextFile(text: text) }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw CocoaError(.fileReadCorruptFile)
        }
        file = try TextFile(data: data)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: file.data())
    }
}
