import AppKit
import ImageIO
import UniformTypeIdentifiers

let width = 1600
let height = 900
let colorSpace = CGColorSpaceCreateDeviceRGB()
guard let context = CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4, space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else { exit(1) }
context.setFillColor(NSColor(calibratedRed: 0.025, green: 0.055, blue: 0.10, alpha: 1).cgColor)
context.fill(CGRect(x: 0, y: 0, width: width, height: height))

let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
    NSColor(calibratedRed: 0.04, green: 0.22, blue: 0.34, alpha: 0.72).cgColor,
    NSColor(calibratedRed: 0.02, green: 0.06, blue: 0.12, alpha: 0).cgColor
] as CFArray, locations: [0, 1])!
context.drawRadialGradient(gradient, startCenter: CGPoint(x: 800, y: 470), startRadius: 10, endCenter: CGPoint(x: 800, y: 470), endRadius: 560, options: [])

func rounded(_ rect: CGRect, radius: CGFloat, fill: CGColor, stroke: CGColor? = nil, line: CGFloat = 1) {
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(fill)
    context.fillPath()
    if let stroke { context.addPath(path); context.setStrokeColor(stroke); context.setLineWidth(line); context.strokePath() }
}

let cyan = NSColor(calibratedRed: 0.27, green: 0.84, blue: 1, alpha: 0.86).cgColor
let amber = NSColor(calibratedRed: 0.96, green: 0.64, blue: 0.28, alpha: 0.9).cgColor
let glass = NSColor(calibratedWhite: 1, alpha: 0.07).cgColor

rounded(CGRect(x: 160, y: 300, width: 250, height: 190), radius: 28, fill: glass, stroke: NSColor.white.withAlphaComponent(0.13).cgColor, line: 2)
rounded(CGRect(x: 1190, y: 300, width: 250, height: 190), radius: 28, fill: glass, stroke: NSColor.white.withAlphaComponent(0.13).cgColor, line: 2)

context.setStrokeColor(cyan); context.setLineWidth(7); context.setLineCap(.round)
context.move(to: CGPoint(x: 410, y: 395)); context.addCurve(to: CGPoint(x: 710, y: 520), control1: CGPoint(x: 520, y: 260), control2: CGPoint(x: 600, y: 610)); context.strokePath()
context.setStrokeColor(amber)
context.move(to: CGPoint(x: 890, y: 520)); context.addCurve(to: CGPoint(x: 1190, y: 395), control1: CGPoint(x: 1000, y: 610), control2: CGPoint(x: 1080, y: 260)); context.strokePath()

context.setFillColor(NSColor(calibratedRed: 0.05, green: 0.12, blue: 0.18, alpha: 1).cgColor)
context.fillEllipse(in: CGRect(x: 610, y: 300, width: 380, height: 380))
context.setStrokeColor(cyan); context.setLineWidth(12); context.strokeEllipse(in: CGRect(x: 625, y: 315, width: 350, height: 350))
context.setStrokeColor(amber); context.setLineWidth(4); context.strokeEllipse(in: CGRect(x: 650, y: 340, width: 300, height: 300))
context.setFillColor(NSColor.white.withAlphaComponent(0.92).cgColor); context.fillEllipse(in: CGRect(x: 780, y: 445, width: 40, height: 40))
context.setStrokeColor(NSColor.white.withAlphaComponent(0.92).cgColor); context.setLineWidth(18); context.strokePath()

rounded(CGRect(x: 225, y: 350, width: 120, height: 85), radius: 12, fill: NSColor(calibratedWhite: 1, alpha: 0.12).cgColor)
context.setStrokeColor(NSColor.white.withAlphaComponent(0.45).cgColor); context.setLineWidth(4); context.stroke(CGRect(x: 245, y: 370, width: 80, height: 44))
rounded(CGRect(x: 1260, y: 335, width: 105, height: 120), radius: 18, fill: NSColor(calibratedWhite: 1, alpha: 0.12).cgColor)
context.setFillColor(NSColor(calibratedRed: 0.22, green: 0.78, blue: 0.95, alpha: 0.75).cgColor); context.fillEllipse(in: CGRect(x: 1307, y: 350, width: 12, height: 12))

guard let cgImage = context.makeImage(), let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: CommandLine.arguments[1]) as CFURL, UTType.png.identifier as CFString, 1, nil) else { exit(1) }
CGImageDestinationAddImage(destination, cgImage, nil)
guard CGImageDestinationFinalize(destination) else { exit(1) }
