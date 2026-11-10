import AppKit
import Foundation

let directory = CommandLine.arguments[1]
try FileManager.default.createDirectory(atPath: directory, withIntermediateDirectories: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let image = NSImage(size: NSSize(width: pixels, height: pixels))
        image.lockFocus()
        let context = NSGraphicsContext.current!.cgContext
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        let rect = NSRect(x: 30, y: 30, width: 964, height: 964)
        NSColor(red: 0.05, green: 0.09, blue: 0.14, alpha: 1).setFill()
        NSBezierPath(roundedRect: rect, xRadius: 220, yRadius: 220).fill()
        NSColor(red: 0.35, green: 0.93, blue: 0.77, alpha: 1).setFill()
        NSBezierPath(roundedRect: NSRect(x: 180, y: 235, width: 664, height: 560), xRadius: 110, yRadius: 110).fill()
        NSColor.black.setFill()
        NSBezierPath(roundedRect: NSRect(x: 365, y: 735, width: 294, height: 110), xRadius: 45, yRadius: 45).fill()
        let attrs: [NSAttributedString.Key: Any] = [.font: NSFont.systemFont(ofSize: 235, weight: .heavy), .foregroundColor: NSColor(red: 0.04, green: 0.1, blue: 0.14, alpha: 1)]
        NSString(string: "EN").draw(at: NSPoint(x: 335, y: 420), withAttributes: attrs)
        NSString(string: "TR").draw(at: NSPoint(x: 417, y: 300), withAttributes: [.font: NSFont.systemFont(ofSize: 105, weight: .bold), .foregroundColor: NSColor.black.withAlphaComponent(0.6)])
        image.unlockFocus()
        let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
        let png = bitmap.representation(using: .png, properties: [:])!
        let suffix = scale == 2 ? "@2x" : ""
        try png.write(to: URL(fileURLWithPath: directory).appendingPathComponent("icon_\(size)x\(size)\(suffix).png"))
    }
}
