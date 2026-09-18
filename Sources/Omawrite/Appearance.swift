import AppKit
import SwiftUI
import CoreText

enum WriterFonts {
    static func register() {
        guard let folder = Bundle.module.url(forResource: "Fonts", withExtension: nil),
              let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        else { return }
        for url in urls where url.pathExtension == "ttf" {
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, nil)
        }
    }

    static func font(size: CGFloat, bold: Bool = false, italic: Bool = false) -> NSFont {
        let face = bold ? (italic ? "BoldItalic" : "Bold") : (italic ? "Italic" : "Regular")
        return NSFont(name: "iAWriterMonoS-\(face)", size: size)
            ?? NSFont.monospacedSystemFont(ofSize: size, weight: bold ? .bold : .regular)
    }
}

struct PaperTheme {
    let dark: Bool
    var background: NSColor { dark ? NSColor(hex: 0x171817) : NSColor(hex: 0xFCFBF8) }
    var foreground: NSColor { dark ? NSColor(hex: 0xE5E5DF) : NSColor(hex: 0x303330) }
    var muted: NSColor { dark ? NSColor(hex: 0x92968D) : NSColor(hex: 0x858980) }
    var marker: NSColor { dark ? NSColor(hex: 0x71766C) : NSColor(hex: 0xA3A69C) }
    var accent: NSColor { dark ? NSColor(hex: 0xC4CDAC) : NSColor(hex: 0x647250) }
    var codeBackground: NSColor { dark ? NSColor(hex: 0x242722) : NSColor(hex: 0xEFEEE7) }
    var selection: NSColor { dark ? NSColor(hex: 0x424B35) : NSColor(hex: 0xDEE5D0) }
}

extension NSColor {
    convenience init(hex: Int) {
        self.init(srgbRed: CGFloat((hex >> 16) & 0xff) / 255,
                  green: CGFloat((hex >> 8) & 0xff) / 255,
                  blue: CGFloat(hex & 0xff) / 255, alpha: 1)
    }
}

enum AppearanceChoice: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var title: String { rawValue.capitalized }
    var colorScheme: ColorScheme? {
        switch self { case .system: nil; case .light: .light; case .dark: .dark }
    }
}
