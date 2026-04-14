import AppKit
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
    private let menuBar = MenuBarManager()
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        menuBar.onOpenSettings = { [weak self] in self?.openSettings() }
        menuBar.setup()
        RuleTimerManager.shared.start()
        StartupCommandRunner.run()
        openSettings()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        openSettings(); return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    // MARK: - Settings Window

    @objc func openSettings() {
        if let w = settingsWindow {
            w.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = HideOnCloseWindow(
            contentRect: NSRect(x: 0, y: 0, width: 860, height: 560),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered, defer: false
        )
        window.title = "Magicer"
        window.toolbarStyle = .unifiedCompact
        window.contentView = NSHostingView(rootView: SettingsView())
        window.center()
        window.setFrameAutosaveName("WorkStopSettings")
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow = window

        NotificationCenter.default.addObserver(
            forName: NSWindow.didUpdateNotification, object: window, queue: .main
        ) { [weak window] _ in
            if window?.title != "Magicer" { window?.title = "Magicer" }
        }
    }
}
