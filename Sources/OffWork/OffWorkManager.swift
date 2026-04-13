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

    private init() {}

    // MARK: - Enter Off-Work Mode

    func enter() {
        guard !isActive else { return }
        isActive = true
        OffWorkState.shared.update(true)

        snapshotAndPauseRules()
        beginActivity()
        buildBlackScreens()
        installKeyMonitor()

        NSApp.activate(ignoringOtherApps: true)
    }

    // MARK: - Exit Off-Work Mode

    func exit(restore: Bool) {
        guard isActive else { return }
        tearDown()

        if restore {
            restoreRules()
        }

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
            let win = NSWindow(
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
            win.makeKeyAndOrderFront(nil)
            win.setFrame(fr, display: true)
            windows.append(win)
        }
    }

    // MARK: - System Sleep Prevention (replaces caffeinate)

    private func beginActivity() {
        activityToken = ProcessInfo.processInfo.beginActivity(
            options: [.idleSystemSleepDisabled, .idleDisplaySleepDisabled, .userInitiated],
            reason: "WorkStop 下班模式"
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

    private func handleEscape() {
        tearDown()

        let alert = NSAlert()
        alert.messageText = "下班模式结束"
        alert.informativeText = "是否恢复工作提醒计时？"
        alert.addButton(withTitle: "恢复提醒")
        alert.addButton(withTitle: "保持暂停")
        alert.alertStyle = .informational

        let response = alert.runModal()
        restoreRules()
        if response != .alertFirstButtonReturn {
            // User chose "保持暂停" — re-disable rules after restore
            for i in RulesStore.shared.rules.indices {
                RulesStore.shared.rules[i].isEnabled = false
            }
        }

        isActive = false
        OffWorkState.shared.update(false)
    }

    private func tearDown() {
        removeKeyMonitor()
        windows.forEach { $0.orderOut(nil) }
        windows.removeAll()
        endActivity()
    }
}
