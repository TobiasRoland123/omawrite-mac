import AppKit

enum AppIconChoice: String, CaseIterable, Identifiable {
    static let preferenceKey = "appIcon"

    case stone
    case obsidian

    var id: String { rawValue }
    var title: String { rawValue.capitalized }

    var image: NSImage? {
        guard let url = Bundle.module.url(
            forResource: rawValue,
            withExtension: "png",
            subdirectory: "AppIcons"
        ) else { return nil }
        return NSImage(contentsOf: url)
    }

    func apply() {
        guard let image else { return }
        NSApp.applicationIconImage = image
    }

    static func applySavedSelection() {
        let savedValue = UserDefaults.standard.string(forKey: preferenceKey)
        (savedValue.flatMap(Self.init(rawValue:)) ?? .stone).apply()
    }
}
