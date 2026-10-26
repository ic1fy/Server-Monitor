#!/usr/bin/env swift

import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift OUTPUT.png\n", stderr)
    exit(2)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
guard
    let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: 1024,
        pixelsHigh: 1024,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ),
    let context = NSGraphicsContext(bitmapImageRep: bitmap)
else {
    fputs("failed to create icon canvas\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context
context.imageInterpolation = .high
NSColor.clear.setFill()
NSRect(x: 0, y: 0, width: 1024, height: 1024).fill()

let outerRect = NSRect(x: 32, y: 32, width: 960, height: 960)
let outerPath = NSBezierPath(roundedRect: outerRect, xRadius: 220, yRadius: 220)
let gradient = NSGradient(colors: [
    NSColor(calibratedRed: 0.08, green: 0.50, blue: 0.98, alpha: 1),
    NSColor(calibratedRed: 0.19, green: 0.23, blue: 0.64, alpha: 1),
])!
gradient.draw(in: outerPath, angle: -55)

NSColor.white.withAlphaComponent(0.10).setFill()
NSBezierPath(ovalIn: NSRect(x: 120, y: 510, width: 780, height: 520)).fill()

let cardSize = NSSize(width: 300, height: 300)
let origins = [
    NSPoint(x: 190, y: 518),
    NSPoint(x: 534, y: 518),
    NSPoint(x: 190, y: 174),
    NSPoint(x: 534, y: 174),
]
let fills: [CGFloat] = [0.28, 0.72, 0.46, 0.90]

for (index, origin) in origins.enumerated() {
    let cardRect = NSRect(origin: origin, size: cardSize)
    let cardPath = NSBezierPath(roundedRect: cardRect, xRadius: 66, yRadius: 66)
    NSColor.white.withAlphaComponent(0.94).setFill()
    cardPath.fill()

    let chipRect = NSRect(x: origin.x + 74, y: origin.y + 104, width: 152, height: 130)
    let chipPath = NSBezierPath(roundedRect: chipRect, xRadius: 28, yRadius: 28)
    NSColor(calibratedRed: 0.10, green: 0.18, blue: 0.34, alpha: 1).setFill()
    chipPath.fill()

    let barBackground = NSBezierPath(
        roundedRect: NSRect(x: origin.x + 48, y: origin.y + 52, width: 204, height: 22),
        xRadius: 11,
        yRadius: 11
    )
    NSColor(calibratedWhite: 0.82, alpha: 1).setFill()
    barBackground.fill()

    let bar = NSBezierPath(
        roundedRect: NSRect(x: origin.x + 48, y: origin.y + 52, width: 204 * fills[index], height: 22),
        xRadius: 11,
        yRadius: 11
    )
    NSColor(calibratedRed: 0.10, green: 0.52, blue: 0.98, alpha: 1).setFill()
    bar.fill()

    for pin in 0..<4 {
        let y = origin.y + 123 + CGFloat(pin) * 29
        NSColor.white.withAlphaComponent(0.78).setFill()
        NSBezierPath(roundedRect: NSRect(x: origin.x + 92, y: y, width: 116, height: 10), xRadius: 5, yRadius: 5).fill()
    }
}

NSGraphicsContext.restoreGraphicsState()

guard let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode icon\n", stderr)
    exit(1)
}

try png.write(to: outputURL)
