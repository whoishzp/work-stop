import AppKit
import QuartzCore

/// Animated stick-figure eyes that scan left and right on the black off-work screen.
class ScanningEyesView: NSView {

    private struct EyePair {
        var baseCenter: CGPoint  // initial anchor position
        var eyeRadius: CGFloat
        var pupilRadius: CGFloat
        var phase: Double        // pupil scan phase
        var speed: Double        // pupil scan speed
        var blinkOffset: Double
        // Float / drift parameters
        var floatPhaseX: Double  // Lissajous phase X
        var floatPhaseY: Double  // Lissajous phase Y
        var floatSpeedX: Double  // drift speed X
        var floatSpeedY: Double  // drift speed Y
        var floatRadius: CGFloat // max drift distance
    }

    private var eyePairs: [EyePair] = []
    private var displayLink: CVDisplayLink?
    private var startTime: CFAbsoluteTime = 0
    private var needsRedrawFlag = true

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        generateEyePairs()
        startAnimation()
    }

    required init?(coder: NSCoder) { fatalError() }

    deinit { stopAnimation() }

    // MARK: - Eye Pair Generation

    private func generateEyePairs() {
        eyePairs = []
        let count = 18
        let w = bounds.width
        let h = bounds.height

        // Sizes range from small to medium (stick-figure style)
        let sizes: [(CGFloat, CGFloat)] = [
            (22, 8), (28, 10), (34, 12), (40, 14), (18, 6),
        ]

        var rng = SystemRandomNumberGenerator()
        var placed: [CGRect] = []

        for _ in 0 ..< count {
            // Try to place without major overlap
            for _ in 0 ..< 30 {
                let sizeIdx = Int.random(in: 0 ..< sizes.count, using: &rng)
                let (er, pr) = sizes[sizeIdx]
                let cx = CGFloat.random(in: er * 3 + 10 ... w - er * 3 - 10, using: &rng)
                let cy = CGFloat.random(in: er * 2 + 10 ... h - er * 2 - 10, using: &rng)
                let rect = CGRect(x: cx - er * 2.5, y: cy - er * 1.5, width: er * 5, height: er * 3)
                if !placed.contains(where: { $0.intersects(rect) }) {
                    placed.append(rect)
                    eyePairs.append(EyePair(
                        baseCenter: CGPoint(x: cx, y: cy),
                        eyeRadius: er,
                        pupilRadius: pr,
                        phase: Double.random(in: 0 ..< .pi * 2, using: &rng),
                        speed: Double.random(in: 0.3 ..< 1.0, using: &rng),
                        blinkOffset: Double.random(in: 0 ..< .pi * 2, using: &rng),
                        floatPhaseX: Double.random(in: 0 ..< .pi * 2, using: &rng),
                        floatPhaseY: Double.random(in: 0 ..< .pi * 2, using: &rng),
                        floatSpeedX: Double.random(in: 0.04 ..< 0.14, using: &rng),
                        floatSpeedY: Double.random(in: 0.03 ..< 0.10, using: &rng),
                        floatRadius: CGFloat.random(in: er * 1.5 ..< er * 4.5, using: &rng)
                    ))
                    break
                }
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }

        let t = CFAbsoluteTimeGetCurrent() - startTime

        for pair in eyePairs {
            // Blink: blink every ~6s, takes 0.15s
            let blinkCycle = sin(pair.blinkOffset + t * 0.8)
            let isBlinking = blinkCycle > 0.94

            // Floating center: Lissajous drift
            let driftX = CGFloat(sin(pair.floatPhaseX + t * pair.floatSpeedX)) * pair.floatRadius
            let driftY = CGFloat(cos(pair.floatPhaseY + t * pair.floatSpeedY)) * pair.floatRadius * 0.6
            let floatCenter = CGPoint(x: pair.baseCenter.x + driftX, y: pair.baseCenter.y + driftY)

            // Eye-to-eye gap = eyeRadius * 2.5
            let gap = pair.eyeRadius * 2.5
            let leftCenter = CGPoint(x: floatCenter.x - gap / 2, y: floatCenter.y)
            let rightCenter = CGPoint(x: floatCenter.x + gap / 2, y: floatCenter.y)

            // Pupil scan: oscillate horizontally with sin
            let scanAmount = pair.eyeRadius * 0.45
            let pupilOffsetX = CGFloat(sin(pair.phase + t * pair.speed * 1.2)) * scanAmount
            // Slight vertical wobble
            let pupilOffsetY = CGFloat(cos(pair.phase + t * pair.speed * 0.7)) * pair.eyeRadius * 0.15

            drawEye(ctx: ctx, center: leftCenter,
                    eyeRadius: pair.eyeRadius, pupilRadius: pair.pupilRadius,
                    pupilOffsetX: pupilOffsetX, pupilOffsetY: pupilOffsetY,
                    isBlinking: isBlinking)

            drawEye(ctx: ctx, center: rightCenter,
                    eyeRadius: pair.eyeRadius, pupilRadius: pair.pupilRadius,
                    pupilOffsetX: pupilOffsetX, pupilOffsetY: pupilOffsetY,
                    isBlinking: isBlinking)

            if !isBlinking {
                drawBrow(ctx: ctx, center: leftCenter, radius: pair.eyeRadius)
                drawBrow(ctx: ctx, center: rightCenter, radius: pair.eyeRadius)
            }
        }
    }

    private func drawEye(ctx: CGContext, center: CGPoint,
                         eyeRadius: CGFloat, pupilRadius: CGFloat,
                         pupilOffsetX: CGFloat, pupilOffsetY: CGFloat,
                         isBlinking: Bool) {
        // Eye white (slightly off-white, dim on black bg)
        let eyeColor = NSColor(white: 0.82, alpha: 0.18)
        let strokeColor = NSColor(white: 0.75, alpha: 0.35)

        if isBlinking {
            // Draw a thin horizontal line (closed eye)
            ctx.setStrokeColor(strokeColor.cgColor)
            ctx.setLineWidth(eyeRadius * 0.22)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: center.x - eyeRadius, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + eyeRadius, y: center.y))
            ctx.strokePath()
            return
        }

        // Eye white ellipse
        let eyeRect = CGRect(
            x: center.x - eyeRadius,
            y: center.y - eyeRadius * 0.75,
            width: eyeRadius * 2,
            height: eyeRadius * 1.5
        )
        ctx.setFillColor(eyeColor.cgColor)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(eyeRadius * 0.12)
        ctx.addEllipse(in: eyeRect)
        ctx.drawPath(using: .fillStroke)

        // Iris
        let irisRadius = pupilRadius * 1.35
        let irisCenter = CGPoint(x: center.x + pupilOffsetX, y: center.y + pupilOffsetY)
        let irisRect = CGRect(
            x: irisCenter.x - irisRadius,
            y: irisCenter.y - irisRadius,
            width: irisRadius * 2,
            height: irisRadius * 2
        )
        ctx.setFillColor(NSColor(white: 0.18, alpha: 0.7).cgColor)
        ctx.addEllipse(in: irisRect)
        ctx.fillPath()

        // Pupil (black dot center)
        let pupilCenter = irisCenter
        let pupilRect = CGRect(
            x: pupilCenter.x - pupilRadius * 0.7,
            y: pupilCenter.y - pupilRadius * 0.7,
            width: pupilRadius * 1.4,
            height: pupilRadius * 1.4
        )
        ctx.setFillColor(NSColor(white: 0.03, alpha: 0.9).cgColor)
        ctx.addEllipse(in: pupilRect)
        ctx.fillPath()

        // Highlight dot
        let hlRadius = pupilRadius * 0.28
        let hlRect = CGRect(
            x: pupilCenter.x + pupilRadius * 0.15,
            y: pupilCenter.y + pupilRadius * 0.15,
            width: hlRadius * 2,
            height: hlRadius * 2
        )
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.55).cgColor)
        ctx.addEllipse(in: hlRect)
        ctx.fillPath()
    }

    private func drawBrow(ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let browY = center.y + radius * 1.25
        let browLeft = CGPoint(x: center.x - radius * 0.7, y: browY + radius * 0.15)
        let browRight = CGPoint(x: center.x + radius * 0.7, y: browY)

        ctx.setStrokeColor(NSColor(white: 0.7, alpha: 0.22).cgColor)
        ctx.setLineWidth(radius * 0.13)
        ctx.setLineCap(.round)
        ctx.move(to: browLeft)
        ctx.addLine(to: browRight)
        ctx.strokePath()
    }

    // MARK: - Animation Loop via CVDisplayLink

    private func startAnimation() {
        startTime = CFAbsoluteTimeGetCurrent()

        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let dl = displayLink else { return }

        CVDisplayLinkSetOutputCallback(dl, { _, _, _, _, _, ctx -> CVReturn in
            let view = Unmanaged<ScanningEyesView>.fromOpaque(ctx!).takeUnretainedValue()
            DispatchQueue.main.async { view.setNeedsDisplay(view.bounds) }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())

        CVDisplayLinkStart(dl)
    }

    private func stopAnimation() {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
        displayLink = nil
    }
}
