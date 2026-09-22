import AppKit
import Combine

@MainActor
final class RecentDocuments: ObservableObject {
    static let shared = RecentDocuments()
    // The app must install its document controller before shared is accessed.
    // Commands can be constructed earlier, so load recents when a menu opens.
    @Published private(set) var urls: [URL] = []
    private var menuObserver: NSObjectProtocol?

    init() {
        menuObserver = NotificationCenter.default.addObserver(forName: NSMenu.didBeginTrackingNotification,
                                                              object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
    }

    deinit {
        if let menuObserver { NotificationCenter.default.removeObserver(menuObserver) }
    }

    func refresh() {
        let current = NSDocumentController.shared.recentDocumentURLs
        if urls != current { urls = current }
    }

    func open(_ url: URL) {
        NSDocumentController.shared.openDocument(withContentsOf: url, display: true) { _, _, error in
            if let error { NSApp.presentError(error) }
        }
    }

    func remember(_ url: URL) {
        NSDocumentController.shared.noteNewRecentDocumentURL(url)
        refresh()
    }

    func clear() {
        NSDocumentController.shared.clearRecentDocuments(nil)
        refresh()
    }
}
