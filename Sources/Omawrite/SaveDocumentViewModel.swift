import Foundation
import Combine

@MainActor
final class SaveDocumentViewModel: ObservableObject {
    @Published var fileName: String { didSet { clearFeedback() } }
    @Published var directoryPath: String { didSet { clearFeedback() } }
    @Published var errorMessage: String?
    @Published var replacementURL: URL?
    @Published var isSaving = false
    let linkedDirectories: [LinkedDirectory]
    let isClosing: Bool
    var onSave: ((URL) -> Void)?
    var onCancel: (() -> Void)?
    var onDiscard: (() -> Void)?

    init(fileName: String, directoryURL: URL, linkedDirectories: [LinkedDirectory], isClosing: Bool) {
        self.fileName = fileName
        directoryPath = (directoryURL.path as NSString).abbreviatingWithTildeInPath
        self.linkedDirectories = linkedDirectories
        self.isClosing = isClosing
    }

    func submit() {
        guard !isSaving else { return }
        do { onSave?(try destinationURL()) }
        catch { errorMessage = error.localizedDescription }
    }

    func destinationURL() throws -> URL {
        var name = fileName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != ".", name != "..",
              name.rangeOfCharacter(from: .controlCharacters) == nil,
              !name.contains("/"), !name.contains(":") else {
            throw ValidationError("Enter a filename without slashes, colons, or line breaks.")
        }
        let ext = (name as NSString).pathExtension.lowercased()
        if ext.isEmpty {
            name += ".md"
        } else if !["md", "markdown", "mdown", "txt", "text"].contains(ext) {
            throw ValidationError("Use .md, .markdown, .mdown, .txt, or .text for this document.")
        }
        let path = (directoryPath as NSString).expandingTildeInPath
        guard path.hasPrefix("/") else {
            throw ValidationError("Enter a full folder path, such as ~/Documents.")
        }
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: path, isDirectory: &isDirectory), isDirectory.boolValue else {
            throw ValidationError("This folder doesn’t exist. Enter an existing folder or choose a location below.")
        }
        return URL(fileURLWithPath: path, isDirectory: true).appendingPathComponent(name).standardizedFileURL
    }

    func chooseDirectory(_ url: URL) {
        directoryPath = (url.path as NSString).abbreviatingWithTildeInPath
    }

    private func clearFeedback() {
        replacementURL = nil
        errorMessage = nil
    }

    private struct ValidationError: LocalizedError {
        let message: String
        init(_ message: String) { self.message = message }
        var errorDescription: String? { message }
    }
}
