import AppKit
import SwiftUI
import UniformTypeIdentifiers
import OmawriteCore

/// AppKit owns persistence; SwiftUI owns the editor and the save sheet.
@objc(WriterDocument)
final class WriterDocument: NSDocument, ObservableObject {
    @Published var content = MarkdownDocument()
    let session = EditorSession()
    private(set) var saveController: SaveDocumentController?

    override class var autosavesInPlace: Bool { true }
    override class var readableTypes: [String] { [UTType.markdown.identifier, UTType.plainText.identifier] }
    override class var writableTypes: [String] { readableTypes }

    override func read(from data: Data, ofType typeName: String) throws {
        content.file = try TextFile(data: data)
    }

    override func data(ofType typeName: String) throws -> Data {
        content.file.data()
    }

    override func makeWindowControllers() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1080, height: 780),
                              styleMask: [.titled, .closable, .miniaturizable, .resizable],
                              backing: .buffered, defer: false)
        window.minSize = NSSize(width: 540, height: 380)
        window.titlebarAppearsTransparent = true
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: DocumentEditorView(document: self))
        let controller = NSWindowController(window: window)
        controller.shouldCloseDocument = true
        addWindowController(controller)
        window.center()
    }

    func edit(_ value: MarkdownDocument) {
        guard value.file != content.file else { return }
        content = value
        // NSTextView registers undo operations with NSDocument, which tracks changes.
    }

    override func runModalSavePanel(for saveOperation: SaveOperationType, delegate: Any?,
                                    didSave didSaveSelector: Selector?, contextInfo: UnsafeMutableRawPointer?) {
        presentSaveSheet(operation: saveOperation, isClosing: false) { saved in
            self.notify(delegate, selector: didSaveSelector, result: saved, contextInfo: contextInfo)
        }
    }

    override func canClose(withDelegate delegate: Any, shouldClose shouldCloseSelector: Selector?,
                           contextInfo: UnsafeMutableRawPointer?) {
        // Autosaved drafts can have a temporary fileURL. They still need a permanent home.
        guard (fileURL == nil && isDocumentEdited) || isDraft else {
            super.canClose(withDelegate: delegate, shouldClose: shouldCloseSelector, contextInfo: contextInfo)
            return
        }
        presentSaveSheet(operation: .saveAsOperation, isClosing: true) { shouldClose in
            self.notify(delegate, selector: shouldCloseSelector, result: shouldClose, contextInfo: contextInfo)
        }
    }

    private func presentSaveSheet(operation: SaveOperationType, isClosing: Bool,
                                  completion: @escaping (Bool) -> Void) {
        guard saveController == nil else {
            saveController?.window?.makeKeyAndOrderFront(nil)
            completion(false)
            return
        }
        if windowForSheet == nil { makeWindowControllers(); showWindows() }
        let controller = SaveDocumentController(document: self, operation: operation, isClosing: isClosing)
        saveController = controller
        controller.present { [self] result in
            saveController = nil
            objectWillChange.send()
            completion(result)
        }
    }

    // NSDocument's save/close hooks use an Objective-C callback with a BOOL and a context pointer.
    private func notify(_ delegate: Any?, selector: Selector?, result: Bool, contextInfo: UnsafeMutableRawPointer?) {
        guard let delegate = delegate as? NSObject, let selector,
              delegate.responds(to: selector), let implementation = delegate.method(for: selector) else { return }
        typealias Callback = @convention(c) (AnyObject, Selector, NSDocument, Bool, UnsafeMutableRawPointer?) -> Void
        unsafeBitCast(implementation, to: Callback.self)(delegate, selector, self, result, contextInfo)
    }
}

private struct DocumentEditorView: View {
    @ObservedObject var document: WriterDocument
    @AppStorage("appearance") private var appearance = AppearanceChoice.system.rawValue

    var body: some View {
        EditorView(document: Binding(get: { document.content }, set: document.edit),
                   fileURL: document.isDraft ? nil : document.fileURL,
                   isEditable: !document.isInViewingMode, session: document.session)
            .preferredColorScheme(AppearanceChoice(rawValue: appearance)?.colorScheme)
    }
}

@MainActor
final class WriterDocumentController: NSDocumentController, ObservableObject {
    static let sharedWriter = WriterDocumentController()
    @Published private(set) var activeDocument: WriterDocument?
    private var observers: [NSObjectProtocol] = []

    override init() {
        super.init()
        for name in [NSWindow.didBecomeMainNotification, NSWindow.didResignMainNotification] {
            observers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] notification in
                MainActor.assumeIsolated {
                    self?.activeDocument = name == NSWindow.didBecomeMainNotification
                        ? (notification.object as? NSWindow)?.windowController?.document as? WriterDocument
                        : nil
                }
            })
        }
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override var defaultType: String? { UTType.markdown.identifier }

    override func documentClass(forType typeName: String) -> AnyClass? {
        UTType(typeName)?.conforms(to: .plainText) == true ? WriterDocument.self : nil
    }

    func newDocument(text: String = "") {
        do {
            let document = try openUntitledDocumentAndDisplay(true) as? WriterDocument
            if !text.isEmpty {
                document?.edit(MarkdownDocument(text: text))
                document?.updateChangeCount(.changeDone)
            }
        } catch { NSApp.presentError(error) }
    }
}
