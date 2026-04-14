import AppKit
import QuartzCore

/// Animated stick-figure eyes that scan left/right AND float freely,
/// bouncing off walls and repelling each other on collision.
class ScanningEyesView: NSView {

    // MARK: - Eye Pair State

    private struct EyePair {
        var pos: CGPoint         // current center
        var vel: CGPoint         // velocity (pts/sec), each pair has different speed
        var eyeRadius: CGFloat
        var pupilRadius: CGFloat
        var scanPhase: Double    // pupil oscillation phase
        var scanSpeed: Double    // pupil scan speed
        var blinkOffset: Double  // blink timing phase

        /// Bounding radius used for collision detection (covers both eyes + gap)
        var collisionRadius: CGFloat { eyeRadius * 2.8 }
    }

    private var eyePairs: [EyePair] = []
    private var displayLink: CVDisplayLink?
    private var lastTime: CFAbsoluteTime = 0
    private var elapsed: Double = 0          // for pupil scan

    // MARK: - Init

    override init(frame: NSRect) {
        super.init(frame: frame)
        wantsLayer = true
        layer?.backgroundColor = .clear
        generateEyePairs()
        startAnimation()
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { stopAnimation() }

    // MARK: - Generate Eye Pairs

    private func generateEyePairs() {
        eyePairs = []
        let count = 18
        let w = bounds.width
        let h = bounds.height

        let sizes: [(CGFloat, CGFloat)] = [
            (20, 7), (26, 9), (32, 11), (38, 13), (17, 6),
        ]

        var rng = SystemRandomNumberGenerator()

        for _ in 0 ..< count {
            for _ in 0 ..< 40 {
                let sizeIdx = Int.random(in: 0 ..< sizes.count, using: &rng)
                let (er, pr) = sizes[sizeIdx]
                let margin = er * 3 + 12
                let cx = CGFloat.random(in: margin ... w - margin, using: &rng)
                let cy = CGFloat.random(in: margin ... h - margin, using: &rng)
                let pos = CGPoint(x: cx, y: cy)

                // Check no overlap with existing pairs
                let cr = er * 2.8
                let overlaps = eyePairs.contains { e in
                    dist(pos, e.pos) < cr + e.collisionRadius + 5
                }
                if overlaps { continue }

                // Each eye pair has a distinctly different speed (20–90 pts/sec)
                let speed = CGFloat.random(in: 20 ..< 90, using: &rng)
                let angle = Double.random(in: 0 ..< .pi * 2, using: &rng)
                let vel = CGPoint(x: CGFloat(cos(angle)) * speed, y: CGFloat(sin(angle)) * speed)

                eyePairs.append(EyePair(
                    pos: pos,
                    vel: vel,
                    eyeRadius: er,
                    pupilRadius: pr,
                    scanPhase: Double.random(in: 0 ..< .pi * 2, using: &rng),
                    scanSpeed: Double.random(in: 0.4 ..< 1.2, using: &rng),
                    blinkOffset: Double.random(in: 0 ..< .pi * 2, using: &rng)
                ))
                break
            }
        }
    }

    // MARK: - Physics Update

    private func update(dt: Double) {
        let w = bounds.width
        let h = bounds.height
        elapsed += dt

        // Move each pair
        for i in eyePairs.indices {
            eyePairs[i].pos.x += eyePairs[i].vel.x * CGFloat(dt)
            eyePairs[i].pos.y += eyePairs[i].vel.y * CGFloat(dt)

            let margin = eyePairs[i].eyeRadius * 3
            // Wall bounce
            if eyePairs[i].pos.x < margin {
                eyePairs[i].pos.x = margin
                eyePairs[i].vel.x = abs(eyePairs[i].vel.x)
            } else if eyePairs[i].pos.x > w - margin {
                eyePairs[i].pos.x = w - margin
                eyePairs[i].vel.x = -abs(eyePairs[i].vel.x)
            }
            if eyePairs[i].pos.y < margin {
                eyePairs[i].pos.y = margin
                eyePairs[i].vel.y = abs(eyePairs[i].vel.y)
            } else if eyePairs[i].pos.y > h - margin {
                eyePairs[i].pos.y = h - margin
                eyePairs[i].vel.y = -abs(eyePairs[i].vel.y)
            }
        }

        // Pair-pair collision: elastic repulsion
        for i in 0 ..< eyePairs.count {
            for j in (i + 1) ..< eyePairs.count {
                let d = dist(eyePairs[i].pos, eyePairs[j].pos)
                let minDist = eyePairs[i].collisionRadius + eyePairs[j].collisionRadius
                guard d < minDist, d > 0 else { continue }

                // Collision normal
                let nx = (eyePairs[j].pos.x - eyePairs[i].pos.x) / d
                let ny = (eyePairs[j].pos.y - eyePairs[i].pos.y) / d

                // Relative velocity along normal
                let rv = (eyePairs[j].vel.x - eyePairs[i].vel.x) * nx
                     + (eyePairs[j].vel.y - eyePairs[i].vel.y) * ny

                // Only resolve if approaching
                if rv < 0 {
                    // Elastic: exchange velocity components along normal
                    // (simplified for equal masses)
                    let impulse: CGFloat = rv
                    eyePairs[i].vel.x += impulse * nx
                    eyePairs[i].vel.y += impulse * ny
                    eyePairs[j].vel.x -= impulse * nx
                    eyePairs[j].vel.y -= impulse * ny
                }

                // Push apart so they don't stick
                let overlap = (minDist - d) / 2 + 1
                eyePairs[i].pos.x -= nx * overlap
                eyePairs[i].pos.y -= ny * overlap
                eyePairs[j].pos.x += nx * overlap
                eyePairs[j].pos.y += ny * overlap
            }
        }
    }

    // MARK: - Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let t = elapsed

        for pair in eyePairs {
            let blinkCycle = sin(pair.blinkOffset + t * 0.8)
            let isBlinking = blinkCycle > 0.94

            let gap = pair.eyeRadius * 2.5
            let leftCenter  = CGPoint(x: pair.pos.x - gap / 2, y: pair.pos.y)
            let rightCenter = CGPoint(x: pair.pos.x + gap / 2, y: pair.pos.y)

            let scanAmount = pair.eyeRadius * 0.45
            let pupilOffsetX = CGFloat(sin(pair.scanPhase + t * pair.scanSpeed * 1.2)) * scanAmount
            let pupilOffsetY = CGFloat(cos(pair.scanPhase + t * pair.scanSpeed * 0.7)) * pair.eyeRadius * 0.15

            drawEye(ctx: ctx, center: leftCenter, er: pair.eyeRadius, pr: pair.pupilRadius,
                    ox: pupilOffsetX, oy: pupilOffsetY, blinking: isBlinking)
            drawEye(ctx: ctx, center: rightCenter, er: pair.eyeRadius, pr: pair.pupilRadius,
                    ox: pupilOffsetX, oy: pupilOffsetY, blinking: isBlinking)

            if !isBlinking {
                drawBrow(ctx: ctx, center: leftCenter, radius: pair.eyeRadius)
                drawBrow(ctx: ctx, center: rightCenter, radius: pair.eyeRadius)
            }
        }
    }

    private func drawEye(ctx: CGContext, center: CGPoint, er: CGFloat, pr: CGFloat,
                         ox: CGFloat, oy: CGFloat, blinking: Bool) {
        let eyeColor    = NSColor(white: 0.82, alpha: 0.18)
        let strokeColor = NSColor(white: 0.75, alpha: 0.35)

        if blinking {
            ctx.setStrokeColor(strokeColor.cgColor)
            ctx.setLineWidth(er * 0.22)
            ctx.setLineCap(.round)
            ctx.move(to: CGPoint(x: center.x - er, y: center.y))
            ctx.addLine(to: CGPoint(x: center.x + er, y: center.y))
            ctx.strokePath()
            return
        }

        let eyeRect = CGRect(x: center.x - er, y: center.y - er * 0.75, width: er * 2, height: er * 1.5)
        ctx.setFillColor(eyeColor.cgColor)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(er * 0.12)
        ctx.addEllipse(in: eyeRect); ctx.drawPath(using: .fillStroke)

        let irisR = pr * 1.35
        let irisC = CGPoint(x: center.x + ox, y: center.y + oy)
        ctx.setFillColor(NSColor(white: 0.18, alpha: 0.7).cgColor)
        ctx.addEllipse(in: CGRect(x: irisC.x - irisR, y: irisC.y - irisR, width: irisR * 2, height: irisR * 2))
        ctx.fillPath()

        ctx.setFillColor(NSColor(white: 0.03, alpha: 0.9).cgColor)
        ctx.addEllipse(in: CGRect(x: irisC.x - pr * 0.7, y: irisC.y - pr * 0.7, width: pr * 1.4, height: pr * 1.4))
        ctx.fillPath()

        let hlR = pr * 0.28
        ctx.setFillColor(NSColor(white: 1.0, alpha: 0.55).cgColor)
        ctx.addEllipse(in: CGRect(x: irisC.x + pr * 0.15, y: irisC.y + pr * 0.15, width: hlR * 2, height: hlR * 2))
        ctx.fillPath()
    }

    private func drawBrow(ctx: CGContext, center: CGPoint, radius: CGFloat) {
        let browY = center.y + radius * 1.25
        ctx.setStrokeColor(NSColor(white: 0.7, alpha: 0.22).cgColor)
        ctx.setLineWidth(radius * 0.13)
        ctx.setLineCap(.round)
        ctx.move(to: CGPoint(x: center.x - radius * 0.7, y: browY + radius * 0.15))
        ctx.addLine(to: CGPoint(x: center.x + radius * 0.7, y: browY))
        ctx.strokePath()
    }

    // MARK: - CVDisplayLink

    private func startAnimation() {
        lastTime = CFAbsoluteTimeGetCurrent()
        CVDisplayLinkCreateWithActiveCGDisplays(&displayLink)
        guard let dl = displayLink else { return }
        CVDisplayLinkSetOutputCallback(dl, { _, _, _, _, _, ctx -> CVReturn in
            let view = Unmanaged<ScanningEyesView>.fromOpaque(ctx!).takeUnretainedValue()
            let now = CFAbsoluteTimeGetCurrent()
            let dt = min(now - view.lastTime, 0.05)   // cap at 50ms to avoid jumps
            view.lastTime = now
            view.update(dt: dt)
            DispatchQueue.main.async { view.setNeedsDisplay(view.bounds) }
            return kCVReturnSuccess
        }, Unmanaged.passUnretained(self).toOpaque())
        CVDisplayLinkStart(dl)
    }

    private func stopAnimation() {
        if let dl = displayLink { CVDisplayLinkStop(dl) }
        displayLink = nil
    }

    // MARK: - Helper

    private func dist(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        let dx = a.x - b.x; let dy = a.y - b.y
        return sqrt(dx * dx + dy * dy)
    }
}
