import AppKit
import Testing
import UniformTypeIdentifiers
@testable import Omawrite

@MainActor
@Suite(.serialized)
struct WriterDocumentTests {
    @Test func documentPreservesEncodingAndLineEndings() throws {
        _ = NSApplication.shared
        let document = WriterDocument()
        let original = Data([0xFF, 0xFE]) + "Hello\r\nworld".data(using: .utf16LittleEndian)!
        try document.read(from: original, ofType: UTType.plainText.identifier)
        #expect(document.content.text == "Hello\nworld")
        document.content.text += "!"
        #expect(try document.data(ofType: UTType.plainText.identifier)
                == Data([0xFF, 0xFE]) + "Hello\r\nworld!".data(using: .utf16LittleEndian)!)
    }

    @Test func saveAssignsURLAndClearsDirtyState() async throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let document = WriterDocument()
        document.fileType = UTType.markdown.identifier
        document.content.text = "# Saved from the app\n"
        document.updateChangeCount(.changeDone)
        let url = directory.appendingPathComponent("Note.md")
        try await document.save(to: url, ofType: UTType.markdown.identifier, for: .saveAsOperation)
        #expect(document.fileURL == url)
        #expect(!document.isDocumentEdited)
        #expect(try String(contentsOf: url, encoding: .utf8) == document.content.text)
        document.close()
    }

    @Test func failedSaveRetainsChanges() async throws {
        _ = NSApplication.shared
        let document = WriterDocument()
        document.content.text = "Keep these words"
        document.updateChangeCount(.changeDone)
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            .appendingPathComponent("missing-parent/Note.md")
        do {
            try await document.save(to: url, ofType: UTType.markdown.identifier, for: .saveAsOperation)
            Issue.record("Saving to a missing folder should fail")
        } catch {
            #expect(document.isDocumentEdited)
            #expect(document.fileURL == nil)
            #expect(document.content.text == "Keep these words")
        }
    }

    @Test func closingDraftCanBeCancelledOrDiscarded() throws {
        _ = NSApplication.shared
        let document = WriterDocument()
        document.fileType = UTType.markdown.identifier
        document.content.text = "Keep this draft"
        document.updateChangeCount(.changeDone)
        document.makeWindowControllers()
        defer { document.close() }
        let delegate = CloseResult()
        let context = UnsafeMutableRawPointer(bitPattern: 123)
        document.canClose(withDelegate: delegate, shouldClose: #selector(CloseResult.document(_:shouldClose:contextInfo:)), contextInfo: context)
        let model = try #require(document.saveController?.viewModel)
        #expect(model.isClosing)
        model.onCancel?()
        #expect(delegate.result == false)
        #expect(delegate.context == context)
        #expect(document.content.text == "Keep this draft")
        #expect(document.saveController == nil)

        document.canClose(withDelegate: delegate, shouldClose: #selector(CloseResult.document(_:shouldClose:contextInfo:)), contextInfo: nil)
        document.saveController?.viewModel.onDiscard?()
        #expect(delegate.result == true)
        #expect(document.saveController == nil)
    }

    @Test func autosavedDraftStillUsesTheInAppClosePrompt() throws {
        _ = NSApplication.shared
        let document = WriterDocument()
        document.fileURL = FileManager.default.temporaryDirectory.appendingPathComponent("Autosaved draft.md")
        document.isDraft = true
        document.makeWindowControllers()
        defer { document.close() }
        let delegate = CloseResult()
        document.canClose(withDelegate: delegate, shouldClose: #selector(CloseResult.document(_:shouldClose:contextInfo:)), contextInfo: nil)
        let model = try #require(document.saveController?.viewModel)
        #expect(model.isClosing)
        #expect(model.fileName == "Untitled.md")
        model.onCancel?()
        #expect(delegate.result == false)
    }

    @Test func existingFileIsUntouchedUntilReplacementIsConfirmed() throws {
        _ = NSApplication.shared
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("Existing.md")
        try "Original text".write(to: url, atomically: true, encoding: .utf8)
        let document = WriterDocument()
        document.content.text = "Replacement text"
        let controller = SaveDocumentController(document: document, operation: .saveAsOperation, isClosing: false)
        controller.viewModel.fileName = url.lastPathComponent
        controller.viewModel.directoryPath = directory.path
        controller.viewModel.submit()
        #expect(controller.viewModel.replacementURL == url)
        #expect(try String(contentsOf: url, encoding: .utf8) == "Original text")
        #expect(document.fileURL == nil)
    }

    @Test func cancellingWindowCloseKeepsWindowAndEditorUndoWorking() async throws {
        _ = NSApplication.shared
        let document = WriterDocument()
        document.fileType = UTType.markdown.identifier
        NSDocumentController.shared.addDocument(document)
        document.makeWindowControllers()
        document.showWindows()
        defer { document.close() }
        // Let the hosting view finish installing the NSTextView and its responder chain.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        let window = try #require(document.windowForSheet)
        let editor = try #require(document.session.textView)
        window.makeFirstResponder(editor)
        editor.insertText("Keep my draft", replacementRange: NSRange(location: 0, length: 0))
        editor.breakUndoCoalescing()
        #expect(document.content.text == "Keep my draft")
        #expect(editor.undoManager === document.undoManager)
        // NSDocument observes the undo group closing to mark the draft as edited.
        await withCheckedContinuation { continuation in
            DispatchQueue.main.async { continuation.resume() }
        }
        #expect(document.isDocumentEdited)
        window.performClose(nil)
        let model = try #require(document.saveController?.viewModel)
        model.onCancel?()
        #expect(window.isVisible)
        #expect(document.windowControllers.count == 1)
        #expect(NSDocumentController.shared.documents.contains(document))
        #expect(document.content.text == "Keep my draft")
        #expect(document.saveController == nil)
        editor.undoManager?.undo()
        #expect(document.content.text.isEmpty)
    }
}

@MainActor
private final class CloseResult: NSObject {
    var result: Bool?
    var context: UnsafeMutableRawPointer?

    @objc func document(_ document: NSDocument, shouldClose: Bool, contextInfo: UnsafeMutableRawPointer?) {
        result = shouldClose
        context = contextInfo
    }
}
