import AppKit

/// Manages the lifecycle of full-screen overlay windows.
/// Layout building is delegated to OverlayLayouts.swift.
/// The close button component lives in CloseButtonView.swift.
class OverlayManager {
    static var windows: [NSWindow] = []
    static var countdownTimer: Timer?
    static var closeBtns: [CloseButtonView] = []
    static var countdownLabels: [NSTextField] = []

    private static var keyMonitor: Any?
    private static var enterPressCount = 0
    private static var lastEnterTime: Date?
    private static var spaceObserver: NSObjectProtocol?
    private static var onDismiss: (() -> Void)?

    // MARK: - Public API

    static func show(rule: ReminderRule, onDismiss: (() -> Void)? = nil) {
        guard windows.isEmpty else { return }
        OverlayManager.onDismiss = onDismiss
        let theme = ThemeColors.find(rule.themeId)
        closeBtns.removeAll()
        countdownLabels.removeAll()
        enterPressCount = 0
        lastEnterTime = nil

        for screen in NSScreen.screens {
            windows.append(buildWindow(screen: screen, rule: rule, theme: theme))
        }

        NSApp.activate(ignoringOtherApps: true)
        installKeyMonitor()
        installSpaceObserver()

        let closeDelay = rule.canCloseImmediately ? 0 : rule.durationSeconds
        if closeDelay <= 0 {
            closeBtns.forEach { $0.isHidden = false }
            countdownLabels.forEach { $0.stringValue = "" }
        } else {
            startCountdown(seconds: closeDelay)
        }
    }

    static func dismiss() {
        countdownTimer?.invalidate(); countdownTimer = nil
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            spaceObserver = nil
        }
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        closeBtns.removeAll()
        countdownLabels.removeAll()
        enterPressCount = 0
        let callback = onDismiss
        onDismiss = nil
        DispatchQueue.main.async { callback?() }
    }

    private static func installSpaceObserver() {
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { _ in
            guard !windows.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            windows.forEach { $0.orderFrontRegardless() }
        }
    }

    // MARK: - Window Construction

    private static func buildWindow(screen: NSScreen, rule: ReminderRule, theme: ThemeColors) -> NSWindow {
        let fr = screen.frame
        let win = NSWindow(contentRect: fr, styleMask: .borderless, backing: .buffered, defer: false, screen: screen)
        win.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) + 100)
        win.isOpaque = true
        win.backgroundColor = theme.background
        win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        win.ignoresMouseEvents = false
        win.acceptsMouseMovedEvents = true

        let root = OverlayRootView(frame: NSRect(origin: .zero, size: fr.size))
        root.wantsLayer = true
        root.layer?.backgroundColor = theme.background.cgColor
        root.autoresizingMask = [.width, .height]
        buildContent(in: root, rule: rule, theme: theme, size: fr.size)

        win.contentView = root
        win.orderFrontRegardless()
        win.setFrame(fr, display: true)
        return win
    }

    // MARK: - Enter Key Backdoor (4 presses within 3 s)

    private static func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard event.keyCode == 36 else { return event }
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
                    countdownTimer?.invalidate(); countdownTimer = nil
                    countdownLabels.forEach { $0.stringValue = "" }
                    closeBtns.forEach { $0.isHidden = false }
                }
            }
            return nil
        }
    }

    // MARK: - Countdown

    static func startCountdown(seconds: Int) {
        var remaining = seconds
        countdownLabels.forEach { $0.stringValue = "\(remaining) 秒后可关闭…" }
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { timer in
            remaining -= 1
            DispatchQueue.main.async {
                if remaining > 0 {
                    countdownLabels.forEach { $0.stringValue = "\(remaining) 秒后可关闭…" }
                } else {
                    timer.invalidate(); countdownTimer = nil
                    countdownLabels.forEach { $0.stringValue = "" }
                    closeBtns.forEach { $0.isHidden = false }
                }
            }
        }
        RunLoop.main.add(countdownTimer!, forMode: .common)
    }
}
