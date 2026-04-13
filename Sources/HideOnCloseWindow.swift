import AppKit

/// A window that hides itself instead of closing, so it can be re-shown instantly.
class HideOnCloseWindow: NSWindow {
    override func close() {
        orderOut(nil)
    }
}
