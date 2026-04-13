import AppKit

// MARK: - OverlayManager

class OverlayManager {
    private static var windows: [NSWindow] = []
    private static var countdownTimer: Timer?
    private static var closeBtns: [CloseButtonView] = []
    private static var countdownLabels: [NSTextField] = []

    private static var keyMonitor: Any?
    private static var enterPressCount = 0
    private static var lastEnterTime: Date?

    static func show(rule: ReminderRule) {
        guard windows.isEmpty else { return }

        let theme = ThemeColors.find(rule.themeId)
        closeBtns.removeAll()
        countdownLabels.removeAll()
        enterPressCount = 0
        lastEnterTime = nil

        for screen in NSScreen.screens {
            let win = buildWindow(screen: screen, rule: rule, theme: theme)
            windows.append(win)
        }

        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()

        let closeDelay = rule.canCloseImmediately ? 0 : rule.durationSeconds
        if closeDelay <= 0 {
            closeBtns.forEach { $0.isHidden = false }
            countdownLabels.forEach { $0.stringValue = "" }
        } else {
            startCountdown(seconds: closeDelay)
        }
    }

    static func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil
        if let monitor = keyMonitor { NSEvent.removeMonitor(monitor); keyMonitor = nil }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        closeBtns.removeAll()
        countdownLabels.removeAll()
        enterPressCount = 0
    }

    // MARK: - Enter Key Backdoor (4 presses within 3s)

    private static func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 36 { // Return / Enter
                let now = Date()
                if let last = lastEnterTime, now.timeIntervalSince(last) < 3.0 {
                    enterPressCount += 1
                } else {
                    enterPressCount = 1
                }
                lastEnterTime = now

                if enterPressCount >= 4 {
                    enterPressCount = 0
                    DispatchQueue.main.async {
                        countdownTimer?.invalidate()
                        countdownTimer = nil
                        countdownLabels.forEach { $0.stringValue = "" }
                        closeBtns.forEach { $0.isHidden = false }
                    }
                }
                return nil
            }
            return event
        }
    }

    // MARK: - Build Window

    private static func buildWindow(screen: NSScreen, rule: ReminderRule, theme: ThemeColors) -> NSWindow {
        let fr = screen.frame

        let win = NSWindow(
            contentRect: fr,
            styleMask: .borderless,
            backing: .buffered,
            defer: false,
            screen: screen
        )
        win.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) + 100)
        win.isOpaque = true
        win.backgroundColor = theme.background
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        win.ignoresMouseEvents = false
        win.acceptsMouseMovedEvents = true

        let root = RootView(frame: NSRect(origin: .zero, size: fr.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = theme.background.cgColor
        root.autoresizingMask = [.width, .height]

        buildContent(in: root, rule: rule, theme: theme, screenHeight: fr.height)

        win.contentView = root
        win.orderFrontRegardless()
        win.setFrame(fr, display: true)
        return win
    }

    // MARK: - Layout Content

    private static func buildContent(in root: NSView, rule: ReminderRule, theme: ThemeColors, screenHeight: CGFloat) {
        func label(_ text: String, size: CGFloat, weight: NSFont.Weight, color: NSColor, wrap: Bool = false) -> NSTextField {
            let f: NSTextField = wrap ? NSTextField(wrappingLabelWithString: text) : NSTextField(labelWithString: text)
            f.font = .systemFont(ofSize: size, weight: weight)
            f.textColor = color
            f.alignment = .center
            f.translatesAutoresizingMaskIntoConstraints = false
            return f
        }

        let topOffset: CGFloat = screenHeight * 0.22

        let titleLbl = label("⏸  工作中断提醒", size: 60, weight: .black, color: theme.primary)
        let line = NSBox()
        line.boxType = .separator
        line.translatesAutoresizingMaskIntoConstraints = false

        let bodyLbl = label(rule.reminderText, size: 28, weight: .medium, color: theme.secondary, wrap: true)
        let cdLbl = label("", size: 20, weight: .regular, color: NSColor(white: 0.55, alpha: 1))

        let btn = CloseButtonView(theme: theme)
        btn.isHidden = true
        btn.translatesAutoresizingMaskIntoConstraints = false

        [titleLbl, line, bodyLbl, cdLbl, btn].forEach { root.addSubview($0) }
        countdownLabels.append(cdLbl)
        closeBtns.append(btn)

        NSLayoutConstraint.activate([
            titleLbl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            titleLbl.topAnchor.constraint(equalTo: root.topAnchor, constant: topOffset),

            line.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            line.widthAnchor.constraint(equalToConstant: 560),
            line.topAnchor.constraint(equalTo: titleLbl.bottomAnchor, constant: 28),

            bodyLbl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            bodyLbl.widthAnchor.constraint(lessThanOrEqualToConstant: 700),
            bodyLbl.topAnchor.constraint(equalTo: line.bottomAnchor, constant: 40),

            cdLbl.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            cdLbl.topAnchor.constraint(equalTo: bodyLbl.bottomAnchor, constant: 60),

            btn.centerXAnchor.constraint(equalTo: root.centerXAnchor),
            btn.topAnchor.constraint(equalTo: bodyLbl.bottomAnchor, constant: 52),
            btn.widthAnchor.constraint(equalToConstant: 340),
            btn.heightAnchor.constraint(equalToConstant: 64),
        ])
    }

    // MARK: - Countdown

    private static func startCountdown(seconds: Int) {
        var remaining = seconds
        countdownLabels.forEach { $0.stringValue = "\(remaining) 秒后可关闭…" }

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1
            DispatchQueue.main.async {
                if remaining > 0 {
                    countdownLabels.forEach { $0.stringValue = "\(remaining) 秒后可关闭…" }
                } else {
                    timer.invalidate()
                    countdownTimer = nil
                    countdownLabels.forEach { $0.stringValue = "" }
                    closeBtns.forEach { $0.isHidden = false }
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
}

// MARK: - RootView

private class RootView: NSView {
    override var isFlipped: Bool { true }
}

// MARK: - CloseButtonView

private class CloseButtonView: NSView {
    private let theme: ThemeColors
    private var hovered = false { didSet { needsDisplay = true } }

    init(theme: ThemeColors) {
        self.theme = theme
        super.init(frame: .zero)
        wantsLayer = true
        updateTrackingAreas()
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        trackingAreas.forEach { removeTrackingArea($0) }
        addTrackingArea(NSTrackingArea(
            rect: bounds,
            options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil
        ))
    }

    override func mouseEntered(with event: NSEvent) { hovered = true }
    override func mouseExited(with event: NSEvent)  { hovered = false }
    override func mouseUp(with event: NSEvent)      { OverlayManager.dismiss() }

    override func draw(_ dirtyRect: NSRect) {
        let bg = hovered
            ? theme.primary.withAlphaComponent(0.85)
            : theme.primary.withAlphaComponent(0.65)
        bg.setFill()
        NSBezierPath(roundedRect: bounds, xRadius: 14, yRadius: 14).fill()

        let text = "✓   我知道了，开始休息" as NSString
        let attrs: [NSAttributedString.Key: Any] = [
            .font: NSFont.boldSystemFont(ofSize: 24),
            .foregroundColor: NSColor.white,
        ]
        let sz = text.size(withAttributes: attrs)
        let pt = CGPoint(x: (bounds.width - sz.width) / 2, y: (bounds.height - sz.height) / 2 + 1)
        text.draw(at: pt, withAttributes: attrs)
    }

    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .pointingHand)
    }
}
