import AppKit
import Foundation

/// 下班模式 — Swift 封装的全屏黑幕（对应 oblack.py 逻辑）
class OffWorkManager {
    static let shared = OffWorkManager()

    private(set) var isActive = false

    private var windows: [NSWindow] = []
    private var activityToken: NSObjectProtocol?
    private var rulesSnapshot: [UUID: Bool] = [:]
    private var keyMonitor: Any?
    private var spaceObserver: NSObjectProtocol?

    private init() {}

    // MARK: - Enter Off-Work Mode

    func enter() {
        guard !isActive else { return }
        isActive = true
        OffWorkState.shared.update(true)

        snapshotAndPauseRules()
        beginActivity()
        buildBlackScreens()    // calls activate + makeKeyAndOrderFront internally
        installKeyMonitor()
        installSpaceObserver()
    }

    // MARK: - Exit Off-Work Mode

    /// Exit off-work mode. If `skipPasswordCheck` is false and a password is configured, verifies first.
    func exit(restore: Bool, skipPasswordCheck: Bool = false) {
        guard isActive else { return }

        if !skipPasswordCheck && AppSettings.shared.hasPassword {
            guard verifyPassword() else { return }
        }

        tearDown()
        if restore { restoreRules() }
        isActive = false
        OffWorkState.shared.update(false)
    }

    // MARK: - Rules

    private func snapshotAndPauseRules() {
        let rules = RulesStore.shared.rules
        rulesSnapshot = Dictionary(uniqueKeysWithValues: rules.map { ($0.id, $0.isEnabled) })
        for i in RulesStore.shared.rules.indices {
            RulesStore.shared.rules[i].isEnabled = false
        }
    }

    private func restoreRules() {
        for i in RulesStore.shared.rules.indices {
            let id = RulesStore.shared.rules[i].id
            if let wasEnabled = rulesSnapshot[id] {
                RulesStore.shared.rules[i].isEnabled = wasEnabled
            }
        }
        rulesSnapshot.removeAll()
    }

    // MARK: - Black Screen Windows

    private func buildBlackScreens() {
        windows.removeAll()

        for screen in NSScreen.screens {
            let fr = screen.frame
            let win = OverlayNSWindow(
                contentRect: fr,
                styleMask: .borderless,
                backing: .buffered,
                defer: false,
                screen: screen
            )
            win.level = NSWindow.Level(rawValue: Int(NSWindow.Level.screenSaver.rawValue) + 150)
            win.isOpaque = true
            win.backgroundColor = .black
            win.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
            win.ignoresMouseEvents = false

            // Animated scanning eyes overlay
            let eyesView = ScanningEyesView(frame: NSRect(origin: .zero, size: fr.size))
            eyesView.autoresizingMask = [.width, .height]
            win.contentView?.addSubview(eyesView)

            win.setFrame(fr, display: false)
            windows.append(win)
        }

        // Show all windows after construction
        NSApp.activate(ignoringOtherApps: true)
        windows.forEach { $0.makeKeyAndOrderFront(nil) }

        // Delayed retry to cover full-screen dedicated Spaces on extended monitors
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) { [weak self] in
            guard let self, self.isActive else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }

    // MARK: - System Sleep Prevention (replaces caffeinate)

    private func beginActivity() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated],
            reason: "Magicer 下班模式"
        )
    }

    private func endActivity() {
        if let token = activityToken {
            ProcessInfo.processInfo.endActivity(token)
            activityToken = nil
        }
    }

    // MARK: - Key Monitor (Esc to exit)

    private func installKeyMonitor() {
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                DispatchQueue.main.async { self?.handleEscape() }
                return nil
            }
            return event
        }
    }

    private func removeKeyMonitor() {
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func installSpaceObserver() {
        spaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self, self.isActive, !self.windows.isEmpty else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.windows.forEach { $0.makeKeyAndOrderFront(nil) }
        }
    }

    private func removeSpaceObserver() {
        if let obs = spaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            spaceObserver = nil
        }
    }

    private func handleEscape() {
        // Password check if configured
        if AppSettings.shared.hasPassword {
            guard verifyPassword() else { return } // wrong password or cancelled → stay black
        }

        tearDown()
        askRestoreRules()

        isActive = false
        OffWorkState.shared.update(false)
    }

    /// Returns true if password matches or user entered correctly.
    private func verifyPassword() -> Bool {
        // Hide black screens first so the alert is visible above them
        windows.forEach { $0.orderOut(nil) }
        NSApp.activate(ignoringOtherApps: true)

        let alert = NSAlert()
        alert.messageText = "解锁下班模式"
        alert.informativeText = "请输入退出密码"
        alert.alertStyle = .informational
        alert.addButton(withTitle: "确定")
        alert.addButton(withTitle: "取消")

        let input = NSSecureTextField(frame: NSRect(x: 0, y: 0, width: 240, height: 24))
        input.placeholderString = "输入密码"
        alert.accessoryView = input

        // Force layout so the alert window exists, then set first responder
        alert.layout()
        alert.window.initialFirstResponder = input

        let response = alert.runModal()
        let correct = response == .alertFirstButtonReturn
            && input.stringValue == AppSettings.shared.offWorkPassword

        if !correct {
            // Wrong password or cancelled — restore black screens
            windows.forEach { $0.makeKeyAndOrderFront(nil) }
            NSApp.activate(ignoringOtherApps: true)
        }

        return correct
    }

    private func askRestoreRules() {
        let alert = NSAlert()
        alert.messageText = "下班模式结束"
        alert.informativeText = "是否恢复工作提醒计时？"
        alert.addButton(withTitle: "恢复提醒")
        alert.addButton(withTitle: "保持暂停")
        alert.alertStyle = .informational

        let response = alert.runModal()
        restoreRules()
        if response != .alertFirstButtonReturn {
            for i in RulesStore.shared.rules.indices {
                RulesStore.shared.rules[i].isEnabled = false
            }
        }
    }

    private func tearDown() {
        removeKeyMonitor()
        removeSpaceObserver()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        endActivity()
    }
}
