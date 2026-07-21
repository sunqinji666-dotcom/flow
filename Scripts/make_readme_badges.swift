import AppKit
import CoreText
import ImageIO
import UniformTypeIdentifiers

struct Badge {
    let label: String
    let value: String
    let accent: NSColor
}

func drawText(_ text: String, at point: CGPoint, fontSize: CGFloat, weight: NSFont.Weight, color: NSColor, in context: CGContext) {
    let font = NSFont.systemFont(ofSize: fontSize, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: color
    ]
    let line = CTLineCreateWithAttributedString(NSAttributedString(string: text, attributes: attributes))
    context.textPosition = point
    CTLineDraw(line, context)
}

func roundedRect(_ rect: CGRect, radius: CGFloat, fill: NSColor, stroke: NSColor, in context: CGContext) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill.cgColor)
    context.fillPath()
    context.addPath(path)
    context.setStrokeColor(stroke.cgColor)
    context.setLineWidth(2)
    context.strokePath()
}

func savePNG(width: Int, height: Int, path: String, draw: (CGContext) -> Void) {
    let space = CGColorSpaceCreateDeviceRGB()
    let info = CGImageAlphaInfo.premultipliedLast.rawValue
    guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: space, bitmapInfo: info) else { exit(1) }
    context.clear(CGRect(x: 0, y: 0, width: width, height: height))
    draw(context)
    guard let image = context.makeImage(),
          let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: path) as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else { exit(1) }
}

let output = CommandLine.arguments[1]
let badges = [
    Badge(label: "VERSION", value: "1.1.0", accent: NSColor(calibratedRed: 0.31, green: 0.84, blue: 1.0, alpha: 1)),
    Badge(label: "PLATFORM", value: "macOS 14+", accent: NSColor(calibratedRed: 0.68, green: 0.74, blue: 0.82, alpha: 1)),
    Badge(label: "ARCH", value: "Apple Silicon", accent: NSColor(calibratedRed: 0.95, green: 0.67, blue: 0.34, alpha: 1)),
    Badge(label: "SWIFT", value: "5.9+", accent: NSColor(calibratedRed: 1.0, green: 0.47, blue: 0.28, alpha: 1)),
    Badge(label: "PRIVACY", value: "Private by default", accent: NSColor(calibratedRed: 0.37, green: 0.91, blue: 0.68, alpha: 1))
]

savePNG(width: 1800, height: 170, path: output + "/readme-status.png") { context in
    let itemWidth: CGFloat = 336
    for (index, badge) in badges.enumerated() {
        let x = CGFloat(index) * 360 + 12
        let rect = CGRect(x: x, y: 18, width: itemWidth, height: 134)
        roundedRect(rect, radius: 28, fill: NSColor(calibratedRed: 0.035, green: 0.07, blue: 0.12, alpha: 1), stroke: NSColor.white.withAlphaComponent(0.16), in: context)
        context.setFillColor(badge.accent.cgColor)
        context.fillEllipse(in: CGRect(x: x + 24, y: 96, width: 12, height: 12))
        drawText(badge.label, at: CGPoint(x: x + 48, y: 91), fontSize: 20, weight: .bold, color: NSColor.white.withAlphaComponent(0.58), in: context)
        drawText(badge.value, at: CGPoint(x: x + 24, y: 42), fontSize: 30, weight: .semibold, color: NSColor.white.withAlphaComponent(0.96), in: context)
    }
}

func drawButton(path: String, title: String, subtitle: String, accent: NSColor) {
    savePNG(width: 720, height: 190, path: path) { context in
        let rect = CGRect(x: 8, y: 8, width: 704, height: 174)
        roundedRect(rect, radius: 38, fill: NSColor(calibratedRed: 0.035, green: 0.07, blue: 0.12, alpha: 1), stroke: accent.withAlphaComponent(0.65), in: context)
        context.setFillColor(accent.cgColor)
        context.fillEllipse(in: CGRect(x: 42, y: 112, width: 18, height: 18))
        drawText(title, at: CGPoint(x: 82, y: 92), fontSize: 40, weight: .bold, color: NSColor.white, in: context)
        drawText(subtitle, at: CGPoint(x: 82, y: 48), fontSize: 23, weight: .medium, color: NSColor.white.withAlphaComponent(0.62), in: context)
    }
}

drawButton(path: output + "/readme-star.png", title: "Star Flow", subtitle: "Support the project on GitHub", accent: NSColor(calibratedRed: 0.96, green: 0.68, blue: 0.30, alpha: 1))
drawButton(path: output + "/readme-release.png", title: "Download v1.1.0", subtitle: "Latest macOS arm64 release", accent: NSColor(calibratedRed: 0.30, green: 0.84, blue: 1.0, alpha: 1))
