import AppKit
import ServiceManagement
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        RuleTimerManager.shared.start()
        openSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        return false
    }

    // MARK: - Status Bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let btn = statusItem.button {
            btn.image = NSImage(systemSymbolName: "clock.badge.exclamationmark", accessibilityDescription: "WorkStop")
            btn.image?.isTemplate = true
        }

        rebuildMenu()
    }

    func rebuildMenu() {
        let menu = NSMenu()

        let titleItem = NSMenuItem(title: "WorkStop — 工作提醒", action: nil, keyEquivalent: "")
        titleItem.isEnabled = false
        menu.addItem(titleItem)
        menu.addItem(.separator())

        menu.addItem(NSMenuItem(title: "打开设置…", action: #selector(openSettings), keyEquivalent: ","))
        menu.addItem(.separator())

        let loginItem = NSMenuItem(title: "开机自启", action: #selector(toggleLoginItem), keyEquivalent: "")
        loginItem.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        loginItem.tag = 1
        menu.addItem(loginItem)

        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "退出 WorkStop", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        statusItem.menu = menu
    }

    // MARK: - Settings Window

    @objc func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let contentView = SettingsView()
        let hosting = NSHostingView(rootView: contentView)

        let window = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 520),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "WorkStop"
        window.contentView = hosting
        window.center()
        window.setFrameAutosaveName("WorkStopSettings")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window
    }

    // MARK: - Login Item

    @objc private func toggleLoginItem() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            // Show error only if it's a real failure, not a user-cancel
            let msg = "开机自启设置失败：\(error.localizedDescription)"
            let alert = NSAlert()
            alert.messageText = msg
            alert.runModal()
        }

        if let item = statusItem.menu?.item(withTag: 1) {
            item.state = (SMAppService.mainApp.status == .enabled) ? .on : .off
        }
    }
}
