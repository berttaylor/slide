import AppKit

/// Menu bar glyphs, drawn as template images so they follow light and dark menu bars.
@MainActor
enum Icons {
    /// The Slide mark: three slots fading in, read left to right.
    static let mark = template(width: 18) { rect in
        let side: CGFloat = 4.5
        let gap: CGFloat = 1.5
        for (index, alpha) in [0.35, 0.65, 1.0].enumerated() {
            let x = rect.midX - (3 * side + 2 * gap) / 2 + CGFloat(index) * (side + gap)
            NSColor.black.withAlphaComponent(alpha).setFill()
            NSBezierPath(roundedRect: CGRect(x: x, y: rect.midY - side / 2, width: side, height: side), xRadius: 1.2, yRadius: 1.2).fill()
        }
    }

    /// Two chevrons sharing one item; each half is its own button.
    static let chevrons = template(width: 30) { rect in
        let config = NSImage.SymbolConfiguration(pointSize: 11, weight: .semibold)
        for (name, x) in [("chevron.left", rect.minX + 3), ("chevron.right", rect.midX + 3)] {
            guard let symbol = NSImage(systemSymbolName: name, accessibilityDescription: nil)?.withSymbolConfiguration(config)
            else { continue }
            symbol.draw(in: CGRect(x: x, y: rect.midY - symbol.size.height / 2, width: symbol.size.width, height: symbol.size.height))
        }
    }

    private static func template(width: CGFloat, draw: @escaping @Sendable (CGRect) -> Void) -> NSImage {
        let image = NSImage(size: NSSize(width: width, height: 18), flipped: false) { rect in
            draw(rect)
            return true
        }
        image.isTemplate = true
        return image
    }
}
