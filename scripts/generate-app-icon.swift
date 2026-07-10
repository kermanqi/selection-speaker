#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    FileHandle.standardError.write(Data("usage: generate-app-icon.swift <output.icns>\n".utf8))
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let iconsetURL = outputURL.deletingPathExtension().appendingPathExtension("iconset")
let fileManager = FileManager.default

try? fileManager.removeItem(at: iconsetURL)
try fileManager.createDirectory(at: iconsetURL, withIntermediateDirectories: true)

let iconFiles: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (filename, size) in iconFiles {
    let image = renderIcon(size: size)
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let png = bitmap.representation(using: .png, properties: [:]) else {
        throw IconError.renderFailed
    }

    try png.write(to: iconsetURL.appendingPathComponent(filename))
}

try? fileManager.removeItem(at: outputURL)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconsetURL.path, "-o", outputURL.path]
try process.run()
process.waitUntilExit()

guard process.terminationStatus == 0 else {
    throw IconError.iconutilFailed(process.terminationStatus)
}

try? fileManager.removeItem(at: iconsetURL)

private func renderIcon(size: CGFloat) -> NSImage {
    let image = NSImage(size: NSSize(width: size, height: size))
    image.lockFocus()

    let bounds = NSRect(x: 0, y: 0, width: size, height: size)
    let cornerRadius = size * 0.22
    let background = NSBezierPath(roundedRect: bounds.insetBy(dx: size * 0.04, dy: size * 0.04), xRadius: cornerRadius, yRadius: cornerRadius)

    NSColor(calibratedRed: 0.12, green: 0.16, blue: 0.20, alpha: 1).setFill()
    background.fill()

    NSColor(calibratedRed: 0.18, green: 0.25, blue: 0.31, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: size * 0.48, y: size * 0.50, width: size * 0.40, height: size * 0.34)).fill()

    drawSpeaker(size: size)
    drawBubble(size: size)
    drawDot(center: NSPoint(x: size * 0.28, y: size * 0.20), radius: size * 0.045, color: .systemYellow)
    drawDot(center: NSPoint(x: size * 0.72, y: size * 0.20), radius: size * 0.045, color: .systemGreen)

    image.unlockFocus()
    return image
}

private func drawSpeaker(size: CGFloat) {
    let body = NSBezierPath()
    body.move(to: NSPoint(x: size * 0.20, y: size * 0.44))
    body.line(to: NSPoint(x: size * 0.31, y: size * 0.44))
    body.line(to: NSPoint(x: size * 0.45, y: size * 0.32))
    body.line(to: NSPoint(x: size * 0.45, y: size * 0.68))
    body.line(to: NSPoint(x: size * 0.31, y: size * 0.56))
    body.line(to: NSPoint(x: size * 0.20, y: size * 0.56))
    body.close()

    NSColor.white.withAlphaComponent(0.94).setFill()
    body.fill()

    NSColor.white.withAlphaComponent(0.9).setStroke()
    for index in 0..<2 {
        let inset = CGFloat(index) * size * 0.07
        let rect = NSRect(
            x: size * 0.43 - inset,
            y: size * 0.35 - inset * 0.2,
            width: size * 0.30 + inset,
            height: size * 0.30 + inset * 0.4
        )
        let wave = NSBezierPath()
        wave.appendArc(
            withCenter: NSPoint(x: rect.minX, y: rect.midY),
            radius: rect.width,
            startAngle: -38,
            endAngle: 38
        )
        wave.lineWidth = size * 0.035
        wave.stroke()
    }
}

private func drawBubble(size: CGFloat) {
    let bubbleRect = NSRect(x: size * 0.52, y: size * 0.49, width: size * 0.26, height: size * 0.19)
    let bubble = NSBezierPath(roundedRect: bubbleRect, xRadius: size * 0.04, yRadius: size * 0.04)
    NSColor.white.withAlphaComponent(0.96).setFill()
    bubble.fill()

    let text = NSAttributedString(
        string: "中",
        attributes: [
            .font: NSFont.boldSystemFont(ofSize: size * 0.105),
            .foregroundColor: NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.20, alpha: 1)
        ]
    )
    let textSize = text.size()
    text.draw(at: NSPoint(x: bubbleRect.midX - textSize.width / 2, y: bubbleRect.midY - textSize.height / 2))
}

private func drawDot(center: NSPoint, radius: CGFloat, color: NSColor) {
    let rect = NSRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)
    NSColor.black.withAlphaComponent(0.22).setStroke()
    let path = NSBezierPath(ovalIn: rect)
    path.lineWidth = max(1, radius * 0.18)
    path.stroke()
    color.setFill()
    path.fill()
}

enum IconError: Error {
    case renderFailed
    case iconutilFailed(Int32)
}
