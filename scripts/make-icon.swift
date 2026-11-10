import AppKit

let output = CommandLine.arguments[1]
let image = NSImage(size: NSSize(width: 1024, height: 1024))
image.lockFocus()
NSColor(red: 1, green: 0.988, blue: 0.973, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 12, y: 12, width: 1000, height: 1000), xRadius: 220, yRadius: 220).fill()
let text = "¥" as NSString
let attributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 580, weight: .semibold),
    .foregroundColor: NSColor(red: 0.71, green: 0.49, blue: 0.08, alpha: 1)
]
let size = text.size(withAttributes: attributes)
text.draw(at: NSPoint(x: (1024 - size.width) / 2, y: 245), withAttributes: attributes)
NSColor(red: 0.93, green: 0.84, blue: 0.81, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 190, y: 180, width: 644, height: 58), xRadius: 29, yRadius: 29).fill()
NSColor(red: 0.82, green: 0.19, blue: 0.16, alpha: 1).setFill()
NSBezierPath(roundedRect: NSRect(x: 190, y: 180, width: 450, height: 58), xRadius: 29, yRadius: 29).fill()
image.unlockFocus()
let bitmap = NSBitmapImageRep(data: image.tiffRepresentation!)!
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
