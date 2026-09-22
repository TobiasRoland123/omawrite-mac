import Foundation
import Testing
@testable import Omawrite

@MainActor
struct SaveDocumentTests {
    private func model(name: String = "Notes", folder: URL = FileManager.default.temporaryDirectory) -> SaveDocumentViewModel {
        SaveDocumentViewModel(fileName: name, directoryURL: folder, linkedDirectories: [], isClosing: false)
    }

    @Test func addsMarkdownExtensionAndPreservesExplicitFormats() throws {
        #expect(try model().destinationURL().lastPathComponent == "Notes.md")
        for name in ["Draft.txt", "NOTES.MD", "Ideas.markdown", "Outline.mdown", "Notes.text"] {
            #expect(try model(name: name).destinationURL().lastPathComponent == name)
        }
    }

    @Test(arguments: ["", " ", ".", "..", "../Other.md", "Folder/Note.md", "Bad:name.md", "No\0.md", "Line\nBreak.md", "Photo.png"])
    func rejectsInvalidNames(name: String) {
        #expect(throws: (any Error).self) { try model(name: name).destinationURL() }
    }

    @Test func expandsHomeAndRejectsMissingOrRelativeFolders() throws {
        let vm = model()
        vm.directoryPath = "~"
        #expect(try vm.destinationURL() == FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Notes.md"))
        vm.directoryPath = "Documents"
        #expect(throws: (any Error).self) { try vm.destinationURL() }
        vm.directoryPath = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).path
        #expect(throws: (any Error).self) { try vm.destinationURL() }
    }

    @Test func changingDestinationRequiresFreshReplacementConfirmation() {
        let vm = model()
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("Notes.md")
        vm.replacementURL = url
        vm.errorMessage = "Previous error"
        vm.fileName = "Different.md"
        #expect(vm.replacementURL == nil)
        #expect(vm.errorMessage == nil)
        vm.replacementURL = url
        vm.directoryPath = "~/Documents"
        #expect(vm.replacementURL == nil)
    }

    @Test func invalidOrBusySubmissionDoesNotStartWriting() {
        let vm = model(name: "../Note.md")
        var writes = 0
        vm.onSave = { _ in writes += 1 }
        vm.submit()
        #expect(writes == 0)
        #expect(vm.errorMessage != nil)
        vm.fileName = "Note.md"
        vm.isSaving = true
        vm.submit()
        #expect(writes == 0)
    }
}
