import Foundation

/// Result of running one startup command (manual run uses this for UI feedback only; not persisted).
struct StartupCommandRunOutcome {
    let label: String
    let commandPreview: String
    let success: Bool
    let exitCode: Int?
    let errorDetail: String?
}

/// Executes all enabled boot-startup commands, but only once per machine boot.
/// Subsequent app relaunches within the same boot session are silently skipped.
enum StartupCommandRunner {

    private static let kLastRunKey = "magicer_startup_last_run"

    /// System boot time derived from process uptime.
    private static var bootTime: Date {
        Date().addingTimeInterval(-ProcessInfo.processInfo.systemUptime)
    }

    /// Returns true only if we haven't run commands since the last machine boot.
    private static var shouldRunThisBoot: Bool {
        let lastRun = UserDefaults.standard.double(forKey: kLastRunKey)
        guard lastRun > 0 else { return true }   // never ran
        return Date(timeIntervalSince1970: lastRun) < bootTime
    }

    /// Called automatically on app launch — skips if already ran since last boot.
    static func run() {
        guard shouldRunThisBoot else {
            NSLog("[Magicer] Boot-startup commands skipped (already ran this boot session)")
            return
        }
        let commands = AppSettings.shared.startupCommands.filter { $0.isEnabled }
        guard !commands.isEmpty else { return }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: kLastRunKey)
        for cmd in commands {
            execute(label: cmd.label, command: cmd.command, finished: nil)
        }
    }

    /// Runs one command immediately (e.g. from settings). Optional main-thread callback with outcome.
    static func runNow(_ cmd: StartupCommand, finished: ((StartupCommandRunOutcome) -> Void)? = nil) {
        execute(label: cmd.label, command: cmd.command, finished: finished)
    }

    private static func execute(
        label: String,
        command: String,
        finished: ((StartupCommandRunOutcome) -> Void)?
    ) {
        let preview = String(command.prefix(200))

        DispatchQueue.global(qos: .utility).async {
            let outcome: StartupCommandRunOutcome
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/sh")
            task.arguments = ["-c", command]
            task.standardOutput = FileHandle.nullDevice
            task.standardError = FileHandle.nullDevice

            do {
                try task.run()
                task.waitUntilExit()
                let code = task.terminationStatus
                let ok = code == 0
                outcome = StartupCommandRunOutcome(
                    label: label,
                    commandPreview: preview,
                    success: ok,
                    exitCode: Int(code),
                    errorDetail: ok ? nil : "退出码 \(code)"
                )
                if !ok {
                    NSLog("[Magicer] Startup command '\(label)' exited with status \(code)")
                }
            } catch {
                NSLog("[Magicer] Startup command '\(label)' failed: \(error)")
                outcome = StartupCommandRunOutcome(
                    label: label,
                    commandPreview: preview,
                    success: false,
                    exitCode: nil,
                    errorDetail: error.localizedDescription
                )
            }

            if let finished = finished {
                DispatchQueue.main.async { finished(outcome) }
            }
        }
    }
}
