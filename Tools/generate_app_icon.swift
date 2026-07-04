import AppKit

struct IconSize {
    let filename: String
    let pixels: Int
}

let sizes = [
    IconSize(filename: "icon_16x16.png", pixels: 16),
    IconSize(filename: "icon_16x16@2x.png", pixels: 32),
    IconSize(filename: "icon_32x32.png", pixels: 32),
    IconSize(filename: "icon_32x32@2x.png", pixels: 64),
    IconSize(filename: "icon_128x128.png", pixels: 128),
    IconSize(filename: "icon_128x128@2x.png", pixels: 256),
    IconSize(filename: "icon_256x256.png", pixels: 256),
    IconSize(filename: "icon_256x256@2x.png", pixels: 512),
    IconSize(filename: "icon_512x512.png", pixels: 512),
    IconSize(filename: "icon_512x512@2x.png", pixels: 1024)
]

let outputDirectory = URL(fileURLWithPath: "FinderToolkit/Assets.xcassets/AppIcon.appiconset", isDirectory: true)

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

func drawIcon(in rect: CGRect) {
    let scale = rect.width / 1024
    func s(_ value: CGFloat) -> CGFloat { value * scale }

    NSGraphicsContext.current?.imageInterpolation = .high
    NSGraphicsContext.current?.shouldAntialias = true

    let bgRect = rect.insetBy(dx: s(62), dy: s(62))
    let bgPath = NSBezierPath(roundedRect: bgRect, xRadius: s(224), yRadius: s(224))

    NSShadow().apply {
        $0.shadowOffset = NSSize(width: 0, height: -s(28))
        $0.shadowBlurRadius = s(42)
        $0.shadowColor = color(20, 32, 46, 0.28)
    }

    let gradient = NSGradient(colors: [
        color(22, 185, 208),
        color(42, 113, 220),
        color(70, 66, 185)
    ])!
    gradient.draw(in: bgPath, angle: 315)
    NSShadow().set()

    let topGlow = NSBezierPath(roundedRect: bgRect.insetBy(dx: s(26), dy: s(26)), xRadius: s(196), yRadius: s(196))
    color(255, 255, 255, 0.18).setStroke()
    topGlow.lineWidth = s(18)
    topGlow.stroke()

    let folder = NSBezierPath()
    folder.move(to: CGPoint(x: s(196), y: s(320)))
    folder.line(to: CGPoint(x: s(196), y: s(666)))
    folder.curve(to: CGPoint(x: s(254), y: s(724)), controlPoint1: CGPoint(x: s(196), y: s(700)), controlPoint2: CGPoint(x: s(220), y: s(724)))
    folder.line(to: CGPoint(x: s(414), y: s(724)))
    folder.curve(to: CGPoint(x: s(462), y: s(762)), controlPoint1: CGPoint(x: s(438), y: s(724)), controlPoint2: CGPoint(x: s(446), y: s(762)))
    folder.line(to: CGPoint(x: s(592), y: s(762)))
    folder.curve(to: CGPoint(x: s(646), y: s(716)), controlPoint1: CGPoint(x: s(626), y: s(762)), controlPoint2: CGPoint(x: s(646), y: s(742)))
    folder.line(to: CGPoint(x: s(768), y: s(716)))
    folder.curve(to: CGPoint(x: s(828), y: s(656)), controlPoint1: CGPoint(x: s(802), y: s(716)), controlPoint2: CGPoint(x: s(828), y: s(690)))
    folder.line(to: CGPoint(x: s(828), y: s(320)))
    folder.curve(to: CGPoint(x: s(766), y: s(258)), controlPoint1: CGPoint(x: s(828), y: s(286)), controlPoint2: CGPoint(x: s(802), y: s(258)))
    folder.line(to: CGPoint(x: s(258), y: s(258)))
    folder.curve(to: CGPoint(x: s(196), y: s(320)), controlPoint1: CGPoint(x: s(222), y: s(258)), controlPoint2: CGPoint(x: s(196), y: s(286)))
    folder.close()

    NSShadow().apply {
        $0.shadowOffset = NSSize(width: 0, height: -s(18))
        $0.shadowBlurRadius = s(28)
        $0.shadowColor = color(4, 24, 48, 0.25)
    }
    NSGradient(colors: [color(250, 252, 255), color(210, 238, 255)])!.draw(in: folder, angle: 90)
    NSShadow().set()

    color(9, 83, 144, 0.24).setStroke()
    folder.lineWidth = s(8)
    folder.stroke()

    let divider = NSBezierPath()
    divider.move(to: CGPoint(x: s(512), y: s(700)))
    divider.curve(to: CGPoint(x: s(512), y: s(300)), controlPoint1: CGPoint(x: s(494), y: s(580)), controlPoint2: CGPoint(x: s(530), y: s(450)))
    color(65, 128, 190, 0.42).setStroke()
    divider.lineWidth = s(9)
    divider.lineCapStyle = .round
    divider.stroke()

    color(23, 64, 105).setFill()
    NSBezierPath(ovalIn: CGRect(x: s(334), y: s(524), width: s(42), height: s(42))).fill()
    NSBezierPath(ovalIn: CGRect(x: s(638), y: s(524), width: s(42), height: s(42))).fill()

    let smile = NSBezierPath()
    smile.move(to: CGPoint(x: s(362), y: s(412)))
    smile.curve(to: CGPoint(x: s(486), y: s(392)), controlPoint1: CGPoint(x: s(398), y: s(370)), controlPoint2: CGPoint(x: s(450), y: s(362)))
    color(23, 64, 105, 0.78).setStroke()
    smile.lineWidth = s(20)
    smile.lineCapStyle = .round
    smile.stroke()

    let path = NSBezierPath()
    path.move(to: CGPoint(x: s(606), y: s(444)))
    path.line(to: CGPoint(x: s(688), y: s(444)))
    path.line(to: CGPoint(x: s(688), y: s(532)))
    path.line(to: CGPoint(x: s(752), y: s(532)))
    path.lineCapStyle = .round
    path.lineJoinStyle = .round
    color(242, 178, 70).setStroke()
    path.lineWidth = s(26)
    path.stroke()

    for point in [CGPoint(x: 606, y: 444), CGPoint(x: 688, y: 444), CGPoint(x: 688, y: 532), CGPoint(x: 752, y: 532)] {
        color(255, 247, 218).setFill()
        NSBezierPath(ovalIn: CGRect(x: s(point.x - 20), y: s(point.y - 20), width: s(40), height: s(40))).fill()
        color(219, 131, 30).setStroke()
        let node = NSBezierPath(ovalIn: CGRect(x: s(point.x - 20), y: s(point.y - 20), width: s(40), height: s(40)))
        node.lineWidth = s(7)
        node.stroke()
    }

    let lensCenter = CGPoint(x: s(670), y: s(400))
    let lensRect = CGRect(x: lensCenter.x - s(92), y: lensCenter.y - s(92), width: s(184), height: s(184))
    NSShadow().apply {
        $0.shadowOffset = NSSize(width: s(8), height: -s(10))
        $0.shadowBlurRadius = s(16)
        $0.shadowColor = color(16, 38, 65, 0.25)
    }
    color(255, 255, 255, 0.58).setFill()
    NSBezierPath(ovalIn: lensRect).fill()
    NSShadow().set()

    color(17, 76, 126).setStroke()
    let lens = NSBezierPath(ovalIn: lensRect)
    lens.lineWidth = s(24)
    lens.stroke()

    let handle = NSBezierPath()
    handle.move(to: CGPoint(x: s(736), y: s(334)))
    handle.line(to: CGPoint(x: s(808), y: s(262)))
    handle.lineCapStyle = .round
    color(17, 76, 126).setStroke()
    handle.lineWidth = s(32)
    handle.stroke()

    let highlight = NSBezierPath()
    highlight.move(to: CGPoint(x: s(620), y: s(438)))
    highlight.curve(to: CGPoint(x: s(674), y: s(474)), controlPoint1: CGPoint(x: s(632), y: s(462)), controlPoint2: CGPoint(x: s(650), y: s(474)))
    color(255, 255, 255, 0.72).setStroke()
    highlight.lineWidth = s(14)
    highlight.lineCapStyle = .round
    highlight.stroke()
}

extension NSShadow {
    func apply(_ configure: (NSShadow) -> Void) {
        configure(self)
        set()
    }
}

for size in sizes {
    guard let bitmap = NSBitmapImageRep(
        bitmapDataPlanes: nil,
        pixelsWide: size.pixels,
        pixelsHigh: size.pixels,
        bitsPerSample: 8,
        samplesPerPixel: 4,
        hasAlpha: true,
        isPlanar: false,
        colorSpaceName: .deviceRGB,
        bytesPerRow: 0,
        bitsPerPixel: 0
    ) else {
        fatalError("Unable to allocate \(size.filename)")
    }

    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    NSColor.clear.setFill()
    NSRect(x: 0, y: 0, width: size.pixels, height: size.pixels).fill()
    drawIcon(in: CGRect(origin: .zero, size: CGSize(width: size.pixels, height: size.pixels)))
    NSGraphicsContext.restoreGraphicsState()

    guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Unable to render \(size.filename)")
    }

    try pngData.write(to: outputDirectory.appendingPathComponent(size.filename))
}
