import Foundation
import SwiftUI
import AppKit
import Combine

@MainActor
final class QuickOpenViewModel: ObservableObject {
    enum Mode {
        case files
        case manageDirectories
    }

    @Published var mode: Mode = .files
    @Published var searchText: String = "" {
        didSet {
            selectedIndex = 0
        }
    }
    @Published var selectedIndex: Int = 0
    var isPresentingSystemPicker = false

    let directoriesStore: LinkedDirectoriesStore
    let recentsStore: RecentDocuments

    private var cancellables = Set<AnyCancellable>()

    var onDismiss: (() -> Void)?

    init(directoriesStore: LinkedDirectoriesStore? = nil, recentsStore: RecentDocuments? = nil) {
        self.directoriesStore = directoriesStore ?? .shared
        self.recentsStore = recentsStore ?? .shared

        self.directoriesStore.$files
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        self.directoriesStore.$directories
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }

    var filteredFiles: [IndexedFile] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let allFiles = directoriesStore.files

        guard !query.isEmpty else {
            // Recents first, then all files sorted by modified date
            let recentURLs = Set(recentsStore.urls.map { $0.standardizedFileURL.path })
            return allFiles.sorted { f1, f2 in
                let r1 = recentURLs.contains(f1.url.standardizedFileURL.path)
                let r2 = recentURLs.contains(f2.url.standardizedFileURL.path)
                if r1 != r2 {
                    return r1 && !r2
                }
                return f1.modifiedDate > f2.modifiedDate
            }
        }

        let queryTokens = query.split(separator: " ").map { String($0) }

        struct ScoredFile {
            let file: IndexedFile
            let score: Int
        }

        var scored: [ScoredFile] = []

        for file in allFiles {
            let nameLower = file.name.lowercased()
            let titleLower = file.title.lowercased()
            let pathLower = file.relativePath.lowercased()
            let dirLower = file.directoryName.lowercased()

            var score = 0

            if titleLower == query || nameLower == query {
                score += 1000
            } else if titleLower.hasPrefix(query) {
                score += 600
            } else if nameLower.hasPrefix(query) {
                score += 500
            } else if titleLower.contains(query) {
                score += 300
            } else if nameLower.contains(query) {
                score += 200
            } else if pathLower.contains(query) || dirLower.contains(query) {
                score += 100
            } else {
                let allMatch = queryTokens.allSatisfy { token in
                    titleLower.contains(token) || nameLower.contains(token) || pathLower.contains(token)
                }
                if allMatch {
                    score += 80
                } else if isSubsequence(query: query, target: titleLower) {
                    score += 40
                }
            }

            if score > 0 {
                let daysAgo = max(0, -file.modifiedDate.timeIntervalSinceNow / 86400)
                let recencyBonus = max(0, 30 - Int(daysAgo))
                score += recencyBonus

                scored.append(ScoredFile(file: file, score: score))
            }
        }

        return scored
            .sorted {
                if $0.score != $1.score {
                    return $0.score > $1.score
                }
                return $0.file.modifiedDate > $1.file.modifiedDate
            }
            .map { $0.file }
    }

    var canCreateNewFile: Bool {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && !directoriesStore.directories.isEmpty
    }

    var newFileNamePreview: String {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        if trimmed.hasSuffix(".md") || trimmed.hasSuffix(".txt") {
            return trimmed
        }
        return "\(trimmed).md"
    }

    var primaryDirectory: LinkedDirectory? {
        directoriesStore.directories.first
    }

    func selectNext() {
        if mode == .files {
            let count = filteredFiles.count + (canCreateNewFile && filteredFiles.isEmpty ? 1 : 0)
            guard count > 0 else { return }
            selectedIndex = (selectedIndex + 1) % count
        }
    }

    func selectPrevious() {
        if mode == .files {
            let count = filteredFiles.count + (canCreateNewFile && filteredFiles.isEmpty ? 1 : 0)
            guard count > 0 else { return }
            selectedIndex = (selectedIndex - 1 + count) % count
        }
    }

    func openSelected() {
        if mode == .manageDirectories {
            mode = .files
            return
        }

        let files = filteredFiles
        if selectedIndex >= 0 && selectedIndex < files.count {
            open(file: files[selectedIndex])
        } else if canCreateNewFile {
            createNewFile()
        }
    }

    func open(file: IndexedFile) {
        NSDocumentController.shared.openDocument(withContentsOf: file.url, display: true) { [weak self] _, _, error in
            if let error {
                NSApp.presentError(error)
            } else {
                self?.recentsStore.remember(file.url)
                self?.dismiss()
            }
        }
    }

    func createNewFile() {
        guard let dir = primaryDirectory else {
            promptAddDirectory()
            return
        }

        let name = newFileNamePreview
        guard !name.isEmpty else { return }

        let targetURL = dir.url.appendingPathComponent(name)

        do {
            if !FileManager.default.fileExists(atPath: targetURL.path) {
                try "".write(to: targetURL, atomically: true, encoding: .utf8)
            }
            directoriesStore.rescan()
            NSDocumentController.shared.openDocument(withContentsOf: targetURL, display: true) { [weak self] _, _, error in
                if let error {
                    NSApp.presentError(error)
                } else {
                    self?.recentsStore.remember(targetURL)
                    self?.dismiss()
                }
            }
        } catch {
            NSApp.presentError(error)
        }
    }

    func promptAddDirectory() {
        isPresentingSystemPicker = true
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = true
        panel.canCreateDirectories = true
        panel.prompt = "Link Folder"
        panel.message = "Choose folders where you keep your Markdown files and notes."

        panel.begin { [weak self] response in
            self?.isPresentingSystemPicker = false
            guard response == .OK, let self else { return }
            for url in panel.urls {
                self.directoriesStore.addDirectory(url: url)
            }
        }
    }

    func openWithSystemPicker() {
        dismiss()
        DispatchQueue.main.async {
            NSDocumentController.shared.openDocument(nil)
        }
    }

    func removeDirectory(_ directory: LinkedDirectory) {
        directoriesStore.removeDirectory(id: directory.id)
    }

    func dismiss() {
        onDismiss?()
    }

    private func isSubsequence(query: String, target: String) -> Bool {
        var qIdx = query.startIndex
        var tIdx = target.startIndex
        while qIdx < query.endIndex && tIdx < target.endIndex {
            if query[qIdx] == target[tIdx] {
                qIdx = query.index(after: qIdx)
            }
            tIdx = target.index(after: tIdx)
        }
        return qIdx == query.endIndex
    }
}
