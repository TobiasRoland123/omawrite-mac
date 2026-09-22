import AppKit
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class SaveDocumentController: NSWindowController {
    let viewModel: SaveDocumentViewModel
    private let writerDocument: WriterDocument
    private let operation: NSDocument.SaveOperationType
    private var completion: ((Bool) -> Void)?

    init(document: WriterDocument, operation: NSDocument.SaveOperationType, isClosing: Bool) {
        self.writerDocument = document
        self.operation = operation
        let linked = LinkedDirectoriesStore.shared.directories
        let existingURL = document.isDraft ? nil : document.fileURL
        let rememberedPath = UserDefaults.standard.string(forKey: "lastSaveDirectory")
        let rememberedURL = rememberedPath.map { URL(fileURLWithPath: $0, isDirectory: true) }
        let directory = existingURL?.deletingLastPathComponent()
            ?? rememberedURL
            ?? linked.first?.url
            ?? FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser
        viewModel = SaveDocumentViewModel(fileName: existingURL?.lastPathComponent ?? "Untitled.md",
                                          directoryURL: directory, linkedDirectories: linked, isClosing: isClosing)
        let panel = NSPanel(contentRect: .zero, styleMask: [.titled, .fullSizeContentView], backing: .buffered, defer: false)
        panel.title = isClosing ? "Save before closing" : "Save document"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isReleasedWhenClosed = false
        panel.contentView = NSHostingView(rootView: SaveDocumentView(viewModel: viewModel))
        super.init(window: panel)
        viewModel.onSave = { [weak self] url in self?.save(to: url) }
        viewModel.onCancel = { [weak self] in self?.finish(false) }
        viewModel.onDiscard = { [weak self] in self?.finish(true) }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    func present(completion: @escaping (Bool) -> Void) {
        self.completion = completion
        guard let window, let parent = writerDocument.windowForSheet else { finish(false); return }
        parent.makeKeyAndOrderFront(nil)
        parent.beginSheet(window)
    }

    private func save(to url: URL) {
        guard !viewModel.isSaving else { return }
        let normalized = url.resolvingSymlinksInPath().standardizedFileURL
        if NSDocumentController.shared.documents.contains(where: {
            $0 !== writerDocument && $0.fileURL?.resolvingSymlinksInPath().standardizedFileURL == normalized
        }) {
            viewModel.errorMessage = "This file is already open. Choose another name or switch to that document."
            return
        }
        var isDirectory: ObjCBool = false
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
            guard !isDirectory.boolValue else {
                viewModel.errorMessage = "A folder already has this name. Choose another filename."
                return
            }
            if viewModel.replacementURL != url {
                viewModel.replacementURL = url
                return
            }
        }

        viewModel.isSaving = true
        viewModel.errorMessage = nil
        let type = ["txt", "text"].contains(url.pathExtension.lowercased()) ? UTType.plainText.identifier : UTType.markdown.identifier
        writerDocument.save(to: url, ofType: type, for: operation) { [self] error in
            viewModel.isSaving = false
            if let error {
                viewModel.replacementURL = nil
                viewModel.errorMessage = error.localizedDescription
                return
            }
            UserDefaults.standard.set(url.deletingLastPathComponent().path, forKey: "lastSaveDirectory")
            RecentDocuments.shared.remember(url)
            LinkedDirectoriesStore.shared.rescan()
            finish(true)
        }
    }

    private func finish(_ result: Bool) {
        guard let completion else { return }
        self.completion = nil
        if let window {
            window.sheetParent?.endSheet(window)
            window.orderOut(nil)
        }
        completion(result)
    }
}
