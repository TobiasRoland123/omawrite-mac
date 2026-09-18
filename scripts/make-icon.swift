import AppKit

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: swift scripts/make-icon.swift <source.png> <output.iconset>\n", stderr)
    exit(64)
}

let source = URL(fileURLWithPath: CommandLine.arguments[1])
let output = URL(fileURLWithPath: CommandLine.arguments[2])
guard let image = NSImage(contentsOf: source),
      let sourceImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
    fputs("Unable to read icon source at \(source.path)\n", stderr)
    exit(65)
}
guard sourceImage.width == sourceImage.height, sourceImage.width >= 1024 else {
    fputs("Icon source must be a square PNG at least 1024 pixels wide.\n", stderr)
    exit(65)
}

try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

func drawIcon(pixels: Int) -> Data {
    let representation = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: representation)
    NSGraphicsContext.current?.imageInterpolation = .high
    NSImage(cgImage: sourceImage, size: NSSize(width: pixels, height: pixels)).draw(
        in: NSRect(x: 0, y: 0, width: pixels, height: pixels),
        from: .zero,
        operation: .copy,
        fraction: 1
    )
    NSGraphicsContext.restoreGraphicsState()
    return representation.representation(using: .png, properties: [:])!
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(size)x\(size)\(scale == 2 ? "@2x" : "").png"
        try drawIcon(pixels: size * scale).write(to: output.appendingPathComponent(name))
    }
}
