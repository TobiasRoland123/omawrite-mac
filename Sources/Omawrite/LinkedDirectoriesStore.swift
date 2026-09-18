import Foundation
import Combine

struct LinkedDirectory: Identifiable, Codable, Equatable, Hashable, Sendable {
    let id: UUID
    let path: String
    var bookmarkData: Data?
    var customName: String?
    var cachedFileCount: Int

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var displayName: String {
        if let customName, !customName.isEmpty {
            return customName
        }
        return url.lastPathComponent
    }

    init(id: UUID = UUID(), path: String, bookmarkData: Data? = nil, customName: String? = nil, cachedFileCount: Int = 0) {
        self.id = id
        self.path = path
        self.bookmarkData = bookmarkData
        self.customName = customName
        self.cachedFileCount = cachedFileCount
    }
}

struct IndexedFile: Identifiable, Equatable, Hashable, Sendable {
    var id: String { url.path }
    let url: URL
    let name: String
    let title: String
    let relativePath: String
    let directoryName: String
    let directoryURL: URL
    let modifiedDate: Date
    let fileSize: Int64

    var relativeModifiedString: String {
        let now = Date()
        let interval = now.timeIntervalSince(modifiedDate)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let mins = max(1, Int(interval / 60))
            return "\(mins)m ago"
        } else if interval < 86400 {
            let hours = max(1, Int(interval / 3600))
            return "\(hours)h ago"
        } else if interval < 86400 * 7 {
            let days = max(1, Int(interval / 86400))
            return "\(days)d ago"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            return formatter.string(from: modifiedDate)
        }
    }
}

@MainActor
final class LinkedDirectoriesStore: ObservableObject {
    static let shared = LinkedDirectoriesStore()

    private let storageKey = "omawrite_linked_directories_v1"
    private let supportedExtensions: Set<String> = ["md", "markdown", "mdown", "txt", "text"]

    @Published private(set) var directories: [LinkedDirectory] = []
    @Published private(set) var files: [IndexedFile] = []
    @Published private(set) var isScanning: Bool = false

    private init() {
        loadDirectories()
        rescan()
    }

    private func loadDirectories() {
        guard let data = UserDefaults.standard.data(forKey: storageKey) else {
            directories = []
            return
        }
        do {
            directories = try JSONDecoder().decode([LinkedDirectory].self, from: data)
        } catch {
            print("Failed to decode linked directories: \(error)")
            directories = []
        }
    }

    private func saveDirectories() {
        do {
            let data = try JSONEncoder().encode(directories)
            UserDefaults.standard.set(data, forKey: storageKey)
        } catch {
            print("Failed to encode linked directories: \(error)")
        }
    }

    func addDirectory(url: URL) {
        let normalizedURL = url.standardizedFileURL.resolvingSymlinksInPath()
        let path = normalizedURL.path

        // Check if already present
        if directories.contains(where: { $0.path == path }) {
            rescan()
            return
        }

        let bookmark = try? normalizedURL.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let newDir = LinkedDirectory(
            path: path,
            bookmarkData: bookmark,
            customName: normalizedURL.lastPathComponent
        )
        directories.append(newDir)
        saveDirectories()
        rescan()
    }

    func removeDirectory(id: UUID) {
        directories.removeAll { $0.id == id }
        saveDirectories()
        rescan()
    }

    func rescan() {
        let currentDirs = self.directories
        guard !currentDirs.isEmpty else {
            self.files = []
            return
        }

        self.isScanning = true
        let extensions = self.supportedExtensions

        Task.detached(priority: .userInitiated) {
            var scannedFiles: [IndexedFile] = []
            var updatedDirs: [LinkedDirectory] = []

            for directory in currentDirs {
                var dirFileCount = 0
                let dirURL = directory.url
                var isSecurityScoped = false

                if let bookmark = directory.bookmarkData {
                    var isStale = false
                    if let resolved = try? URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale) {
                        isSecurityScoped = resolved.startAccessingSecurityScopedResource()
                    }
                }

                defer {
                    if isSecurityScoped {
                        dirURL.stopAccessingSecurityScopedResource()
                    }
                }

                var isDir: ObjCBool = false
                guard FileManager.default.fileExists(atPath: dirURL.path, isDirectory: &isDir), isDir.boolValue else {
                    var copy = directory
                    copy.cachedFileCount = 0
                    updatedDirs.append(copy)
                    continue
                }

                let keys: [URLResourceKey] = [.isRegularFileKey, .contentModificationDateKey, .fileSizeKey]
                let options: FileManager.DirectoryEnumerationOptions = [.skipsHiddenFiles, .skipsPackageDescendants]

                if let enumerator = FileManager.default.enumerator(
                    at: dirURL,
                    includingPropertiesForKeys: keys,
                    options: options
                ) {
                    let rootPath = dirURL.standardizedFileURL.path

                    while let fileURL = enumerator.nextObject() as? URL {
                        // Depth safeguard: don't enumerate deeper than 10 levels
                        if enumerator.level > 10 {
                            enumerator.skipDescendants()
                            continue
                        }

                        let ext = fileURL.pathExtension.lowercased()
                        guard extensions.contains(ext) else { continue }

                        guard let values = try? fileURL.resourceValues(forKeys: Set(keys)),
                              values.isRegularFile == true else { continue }

                        let filePath = fileURL.standardizedFileURL.path
                        var relativePath = filePath
                        if relativePath.hasPrefix(rootPath) {
                            relativePath = String(relativePath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                        }

                        let modDate = values.contentModificationDate ?? Date.distantPast
                        let fileSize = Int64(values.fileSize ?? 0)
                        let fileName = fileURL.lastPathComponent
                        let fileTitle = fileURL.deletingPathExtension().lastPathComponent

                        let item = IndexedFile(
                            url: fileURL,
                            name: fileName,
                            title: fileTitle,
                            relativePath: relativePath.isEmpty ? fileName : relativePath,
                            directoryName: directory.displayName,
                            directoryURL: dirURL,
                            modifiedDate: modDate,
                            fileSize: fileSize
                        )
                        scannedFiles.append(item)
                        dirFileCount += 1

                        if scannedFiles.count >= 10000 {
                            break
                        }
                    }
                }

                var updatedDir = directory
                updatedDir.cachedFileCount = dirFileCount
                updatedDirs.append(updatedDir)
            }

            // Sort files by modified date descending by default
            scannedFiles.sort { $0.modifiedDate > $1.modifiedDate }

            let finalFiles = scannedFiles
            let finalDirs = updatedDirs

            await MainActor.run {
                self.files = finalFiles
                self.directories = finalDirs
                self.saveDirectories()
                self.isScanning = false
            }
        }
    }
}
