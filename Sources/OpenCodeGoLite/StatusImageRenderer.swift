import AppKit

final class StatusImageRenderer {
    private let font = NSFont.monospacedSystemFont(ofSize: 9.2, weight: .medium)

    func image(line1: String, line2: String) -> NSImage {
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center

        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: NSColor.labelColor,
            .paragraphStyle: paragraph
        ]

        let top = NSAttributedString(string: line1, attributes: attributes)
        let bottom = NSAttributedString(string: line2, attributes: attributes)

        let topSize = top.size()
        let bottomSize = bottom.size()
        let width = max(48, ceil(max(topSize.width, bottomSize.width)) + 8)
        let height: CGFloat = 22
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(origin: .zero, size: image.size).fill()

        let topRect = NSRect(x: 0, y: 10.5, width: width, height: 11)
        let bottomRect = NSRect(x: 0, y: 0.8, width: width, height: 11)
        top.draw(in: topRect)
        bottom.draw(in: bottomRect)
        image.unlockFocus()

        image.isTemplate = false
        return image
    }
}
