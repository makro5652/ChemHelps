import AppKit

/// `ChemHelps --icon <datei.png>` zeichnet das App-Symbol in 1024 × 1024 Pixeln.
enum IconRenderer {
    @MainActor
    static func runIfRequested() -> Bool {
        let arguments = CommandLine.arguments
        guard let flag = arguments.firstIndex(of: "--icon"), flag + 1 < arguments.count else { return false }
        let size = 1024
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
            samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
            bytesPerRow: 0, bitsPerPixel: 0
        ) else { return true }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

        let inset: CGFloat = 100
        let rect = CGRect(x: inset, y: inset, width: CGFloat(size) - 2 * inset, height: CGFloat(size) - 2 * inset)
        let shape = NSBezierPath(roundedRect: rect, xRadius: 185, yRadius: 185)
        NSGradient(colors: [
            NSColor(red: 0.07, green: 0.16, blue: 0.30, alpha: 1),
            NSColor(red: 0.08, green: 0.30, blue: 0.36, alpha: 1),
        ])?.draw(in: shape, angle: -60)

        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let main: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 300, weight: .semibold),
            .foregroundColor: NSColor.white,
            .paragraphStyle: paragraph,
        ]
        let accent: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 300, weight: .semibold),
            .foregroundColor: NSColor(red: 0.40, green: 0.82, blue: 1.0, alpha: 1),
            .paragraphStyle: paragraph,
        ]
        let text = NSMutableAttributedString(string: "H", attributes: main)
        text.append(NSAttributedString(string: "₂", attributes: accent))
        text.append(NSAttributedString(string: "O", attributes: main))
        let textSize = text.size()
        text.draw(in: CGRect(x: rect.minX, y: rect.midY - textSize.height / 2 + 40, width: rect.width, height: textSize.height))

        let arrow = NSAttributedString(string: "→", attributes: [
            .font: NSFont.systemFont(ofSize: 170, weight: .medium),
            .foregroundColor: NSColor.white.withAlphaComponent(0.55),
            .paragraphStyle: paragraph,
        ])
        arrow.draw(in: CGRect(x: rect.minX, y: rect.minY + 70, width: rect.width, height: 220))

        NSGraphicsContext.restoreGraphicsState()
        try? bitmap.representation(using: .png, properties: [:])?.write(to: URL(fileURLWithPath: arguments[flag + 1]))
        return true
    }
}
