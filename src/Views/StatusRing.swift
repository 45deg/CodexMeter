import Cocoa

func ringImage(state: RingState) -> NSImage {
    let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
        func arc(_ percent: Double, radius: CGFloat, alpha: Double, dashed: Bool = false) {
            let path: NSBezierPath
            if percent >= 100 {
                path = NSBezierPath(ovalIn: NSRect(x: 9 - radius, y: 9 - radius, width: radius * 2, height: radius * 2))
            } else {
                path = NSBezierPath()
                path.appendArc(
                    withCenter: NSPoint(x: 9, y: 9), radius: radius, startAngle: 90,
                    endAngle: CGFloat(90 - 360 * percent / 100), clockwise: true)
            }
            path.lineWidth = 1.45
            path.lineCapStyle = .round
            if dashed {
                let pattern: [CGFloat] = [0.6, 2.0]
                pattern.withUnsafeBufferPointer { path.setLineDash($0.baseAddress, count: $0.count, phase: 0) }
            }
            NSColor.black.withAlphaComponent(alpha).setStroke()
            path.stroke()
        }
        func ring(_ value: Double?, radius: CGFloat) {
            guard let value else {
                arc(100, radius: radius, alpha: 0.45, dashed: true)
                return
            }
            arc(100, radius: radius, alpha: 0.18)
            if value > 0 { arc(max(0, min(100, value)), radius: radius, alpha: 1) }
        }
        ring(state.outer, radius: 7.0)
        if state.isDouble { ring(state.inner, radius: 4.0) }
        return true
    }
    image.isTemplate = true
    return image
}
