#!/usr/bin/env swift
// Fallback icon generator. Writes the 1024x1024 master PNG that Scripts/build_icns.sh
// turns into AppIcon.icns: an original, programmatically drawn placeholder
// (rounded-square gradient, white gauge arc with a needle and a small sparkle).
// No third-party artwork. Uses only CoreGraphics + ImageIO, so it runs headless.
// The designed logo replaces the master PNG; this script only runs when it is missing.
//
// Usage: swift Scripts/make_icon.swift [output.png]   (default: Resources/Brand/AppIcon-1024.png)

import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let outputPath = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "Resources/Brand/AppIcon-1024.png"

func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(srgbRed: r / 255, green: g / 255, blue: b / 255, alpha: a)
}

/// Draws the icon on a 1024-unit canvas; the context is pre-scaled to the target size.
func drawIcon(in ctx: CGContext) {
    // macOS icon grid: 824pt body centred on a 1024pt canvas, ~185pt corner radius.
    let body = CGRect(x: 100, y: 100, width: 824, height: 824)
    let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

    // Soft drop shadow under the body.
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: color(0, 0, 0, 0.35))
    ctx.addPath(bodyPath)
    ctx.setFillColor(color(20, 40, 80))
    ctx.fillPath()
    ctx.restoreGState()

    // Diagonal gradient fill: teal (bottom-left) to deep blue (top-right).
    ctx.saveGState()
    ctx.addPath(bodyPath)
    ctx.clip()
    let gradient = CGGradient(
        colorsSpace: CGColorSpace(name: CGColorSpace.sRGB),
        colors: [color(24, 196, 172), color(38, 110, 230), color(58, 52, 170)] as CFArray,
        locations: [0, 0.55, 1]
    )!
    ctx.drawLinearGradient(gradient, start: CGPoint(x: 100, y: 100), end: CGPoint(x: 924, y: 924), options: [])
    ctx.restoreGState()

    // Gauge: a 240-degree arc opening downwards.
    let center = CGPoint(x: 512, y: 470)
    let radius: CGFloat = 250
    let startAngle = CGFloat.pi * (-30.0 / 180.0)  // lower right
    let endAngle = CGFloat.pi * (210.0 / 180.0)    // lower left
    ctx.setLineCap(.round)

    // Track.
    ctx.setStrokeColor(color(255, 255, 255, 0.28))
    ctx.setLineWidth(58)
    ctx.addArc(center: center, radius: radius, startAngle: startAngle, endAngle: endAngle, clockwise: false)
    ctx.strokePath()

    // Filled portion (from the left end, clockwise to ~75%).
    let valueAngle = CGFloat.pi * (20.0 / 180.0)
    ctx.setStrokeColor(color(255, 255, 255))
    ctx.addArc(center: center, radius: radius, startAngle: endAngle, endAngle: valueAngle, clockwise: true)
    ctx.strokePath()

    // Needle pointing at the value.
    let needleLength: CGFloat = 195
    let tip = CGPoint(x: center.x + cos(valueAngle) * needleLength, y: center.y + sin(valueAngle) * needleLength)
    ctx.setLineWidth(34)
    ctx.move(to: center)
    ctx.addLine(to: tip)
    ctx.strokePath()
    ctx.setFillColor(color(255, 255, 255))
    ctx.fillEllipse(in: CGRect(x: center.x - 46, y: center.y - 46, width: 92, height: 92))

    // Four-point sparkle in the upper-left corner.
    drawSparkle(in: ctx, at: CGPoint(x: 300, y: 760), size: 88)
}

func drawSparkle(in ctx: CGContext, at c: CGPoint, size s: CGFloat) {
    let waist = s * 0.22
    let path = CGMutablePath()
    path.move(to: CGPoint(x: c.x, y: c.y + s))
    path.addQuadCurve(to: CGPoint(x: c.x + s, y: c.y), control: CGPoint(x: c.x + waist, y: c.y + waist))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y - s), control: CGPoint(x: c.x + waist, y: c.y - waist))
    path.addQuadCurve(to: CGPoint(x: c.x - s, y: c.y), control: CGPoint(x: c.x - waist, y: c.y - waist))
    path.addQuadCurve(to: CGPoint(x: c.x, y: c.y + s), control: CGPoint(x: c.x - waist, y: c.y + waist))
    path.closeSubpath()
    ctx.addPath(path)
    ctx.setFillColor(color(255, 255, 255, 0.95))
    ctx.fillPath()
}

func renderPNG(size: Int, to url: URL) throws {
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { throw IconError.context(size) }
    ctx.setShouldAntialias(true)
    ctx.interpolationQuality = .high
    ctx.scaleBy(x: CGFloat(size) / 1024, y: CGFloat(size) / 1024)
    drawIcon(in: ctx)
    guard let image = ctx.makeImage(),
          let dest = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)
    else { throw IconError.encode(url.path) }
    CGImageDestinationAddImage(dest, image, nil)
    guard CGImageDestinationFinalize(dest) else { throw IconError.encode(url.path) }
}

enum IconError: Error {
    case context(Int)
    case encode(String)
}

do {
    let output = URL(fileURLWithPath: outputPath)
    try FileManager.default.createDirectory(at: output.deletingLastPathComponent(), withIntermediateDirectories: true)
    try renderPNG(size: 1024, to: output)
    print("Wrote \(output.path)")
} catch {
    FileHandle.standardError.write("make_icon failed: \(error)\n".data(using: .utf8)!)
    exit(1)
}
