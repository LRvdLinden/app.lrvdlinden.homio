import SwiftUI

/// Interactieve kunst: zachte kleurvlekken die je vinger (of je gezicht, met nabijheid aan) volgen.
struct FlowFace: View {
    @EnvironmentObject private var proximity: ProximityMonitor
    @State private var touch: CGPoint?
    @State private var motion = FlowMotion()

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                let target = touch ?? proximity.facePoint
                Canvas { gc, size in
                    motion.step(toward: target)
                    gc.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.black))
                    var layer = gc
                    layer.addFilter(.blur(radius: min(size.width, size.height) * 0.07))
                    layer.blendMode = .plusLighter
                    let side = min(size.width, size.height)
                    for i in 0..<8 {
                        let fi = Double(i)
                        var x = 0.5 + 0.38 * sin(t * (0.11 + fi * 0.017) + fi * 1.7)
                        var y = 0.5 + 0.34 * cos(t * (0.09 + fi * 0.021) + fi * 2.3)
                        let pull = motion.strength * (0.3 + 0.08 * fi.truncatingRemainder(dividingBy: 4))
                        x += (Double(motion.point.x) - x) * pull
                        y += (Double(motion.point.y) - y) * pull
                        let hue = (fi / 8 + t * 0.012).truncatingRemainder(dividingBy: 1)
                        let r = side * CGFloat(0.3 + 0.07 * sin(t * 0.5 + fi))
                        let rect = CGRect(x: CGFloat(x) * size.width - r / 2, y: CGFloat(y) * size.height - r / 2, width: r, height: r)
                        layer.fill(Path(ellipseIn: rect),
                                   with: .color(Color(hue: hue, saturation: 0.75, brightness: 0.95).opacity(0.5)))
                    }
                }
            }
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { g in
                        touch = CGPoint(x: g.location.x / max(1, geo.size.width),
                                        y: g.location.y / max(1, geo.size.height))
                    }
                    .onEnded { _ in touch = nil }
            )
        }
        .ignoresSafeArea()
    }
}

/// Houdt een zacht meebewegend punt bij, zodat loslaten niet schokt.
final class FlowMotion {
    var point = CGPoint(x: 0.5, y: 0.5)
    var strength: Double = 0

    func step(toward target: CGPoint?) {
        if let target {
            point.x += (target.x - point.x) * 0.08
            point.y += (target.y - point.y) * 0.08
            strength += (1 - strength) * 0.06
        } else {
            strength += (0 - strength) * 0.02
        }
    }
}
