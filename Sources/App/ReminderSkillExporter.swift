import Foundation

/// Exports current reminder rules as a Cursor skill file and injects a section into Claude's CLAUDE.md.
/// Cursor auto-loads all `~/.cursor/skills/**` SKILL.md files — no mcp.json config needed.
struct ReminderSkillExporter {

    static let skillDir = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".cursor/skills/magicer-reminders")

    private static let claudeMd = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".claude/CLAUDE.md")

    private static let claudeMarkerBegin = "<!-- magicer-reminders:start -->"
    private static let claudeMarkerEnd   = "<!-- magicer-reminders:end -->"

    // MARK: - Public API

    /// Silent auto-sync: only writes Cursor skill file (called on every rules change).
    @discardableResult
    static func export(rules: [ReminderRule]) -> Bool {
        writeCursorSkill(rules: rules)
    }

    /// Full install: writes Cursor skill + injects/updates Claude CLAUDE.md section.
    /// Returns (cursorOK, claudeOK).
    @discardableResult
    static func installAll(rules: [ReminderRule]) -> (cursor: Bool, claude: Bool) {
        let cursorOK = writeCursorSkill(rules: rules)
        let claudeOK = writeClaudeSection(rules: rules)
        return (cursorOK, claudeOK)
    }

    // MARK: - Cursor

    @discardableResult
    private static func writeCursorSkill(rules: [ReminderRule]) -> Bool {
        let content = buildSkill(rules: rules)
        do {
            try FileManager.default.createDirectory(at: skillDir,
                                                    withIntermediateDirectories: true)
            let url = skillDir.appendingPathComponent("SKILL.md")
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    // MARK: - Claude

    private static func writeClaudeSection(rules: [ReminderRule]) -> Bool {
        let section = buildClaudeSection(rules: rules)
        let fm = FileManager.default
        do {
            var existing = ""
            if fm.fileExists(atPath: claudeMd.path) {
                existing = (try? String(contentsOf: claudeMd, encoding: .utf8)) ?? ""
            }
            let updated = upsertSection(in: existing, section: section)
            try updated.write(to: claudeMd, atomically: true, encoding: .utf8)
            return true
        } catch {
            return false
        }
    }

    /// Replace content between markers, or append if markers absent.
    private static func upsertSection(in text: String, section: String) -> String {
        if let beginRange = text.range(of: claudeMarkerBegin),
           let endRange   = text.range(of: claudeMarkerEnd),
           beginRange.upperBound <= endRange.lowerBound {
            let replacement = claudeMarkerBegin + "\n" + section + "\n" + claudeMarkerEnd
            return text.replacingCharacters(
                in: beginRange.lowerBound..<endRange.upperBound,
                with: replacement
            )
        } else {
            let separator = text.hasSuffix("\n") ? "\n" : "\n\n"
            return text + separator + claudeMarkerBegin + "\n" + section + "\n" + claudeMarkerEnd + "\n"
        }
    }

    // MARK: - Skill content

    private static func buildSkill(rules: [ReminderRule]) -> String {
        let iso = ISO8601DateFormatter()
        var s = ""

        s += """
        # Magicer 定时提醒 — AI Skill

        Use this skill whenever the user wants to **view, add, modify, or delete** reminder rules
        running in the Magicer app on their Mac.

        ---

        ## Current Rules  *(auto-synced on every save)*\n
        """

        if rules.isEmpty {
            s += "_No rules configured._\n"
        } else {
            for r in rules {
                let status = r.isEnabled ? "✅" : "⏸"
                s += "\n### \(status) \(r.name)\n"
                s += "- id: `\(r.id)`\n"
                s += "- action: **\(r.actionKind == .script ? "script (shell)" : "desktop overlay")**\n"
                switch r.triggerMode {
                case .interval:
                    s += "- trigger: every **\(r.intervalMinutes) minutes**\n"
                case .scheduled:
                    let times = r.scheduledTimes.map { $0.displayText }.joined(separator: ", ")
                    s += "- trigger: daily @ **\(times.isEmpty ? "(no times set)" : times)**\n"
                case .once:
                    s += "- trigger: once @ **\(iso.string(from: r.onceDate))**\n"
                }
                if r.actionKind == .desktop {
                    if r.followupMinutes > 0 {
                        s += "- followup: \(r.followupMinutes) min after dismissal\n"
                    }
                    s += "- overlay text: \"\(r.reminderText)\"\n"
                    s += "- duration: \(r.durationSeconds)s · theme: \(r.themeId)\n"
                } else {
                    let cmd = r.shellCommand.trimmingCharacters(in: .whitespacesAndNewlines)
                    s += "- shell: `\(cmd.isEmpty ? "(empty)" : cmd.replacingOccurrences(of: "`", with: "'"))`\n"
                    if !r.logDirectoryPath.isEmpty {
                        s += "- log dir: `\(r.logDirectoryPath)`\n"
                    }
                }
            }
        }

        s += """

        ---

        ## How to Interact

        Magicer runs an embedded HTTP server on **`http://127.0.0.1:18879`** while the app is open.
        Dates use ISO 8601 (e.g. `2026-04-15T09:00:00Z`).

        ### Read
        ```bash
        curl http://127.0.0.1:18879/reminders
        ```

        ### Add a rule
        ```bash
        curl -X POST http://127.0.0.1:18879/reminders \\
          -H 'Content-Type: application/json' \\
          -d '{
            "id": "<generate a UUID>",
            "name": "喝水提醒",
            "actionKind": "desktop",
            "triggerMode": "interval",
            "intervalMinutes": 60,
            "scheduledTimes": [],
            "onceDate": "2026-04-15T09:00:00Z",
            "followupMinutes": 0,
            "durationSeconds": 10,
            "canCloseImmediately": false,
            "reminderText": "该喝水了！",
            "themeId": "blue-calm",
            "isEnabled": true,
            "shellCommand": "",
            "logDirectoryPath": ""
          }'
        ```

        ### Toggle enabled/disabled
        ```bash
        curl -X PUT http://127.0.0.1:18879/reminders/{id}/toggle
        ```

        ### Delete
        ```bash
        curl -X DELETE http://127.0.0.1:18879/reminders/{id}
        ```

        ### triggerMode values
        | value | meaning |
        | --- | --- |
        | `interval` | repeat every N minutes |
        | `scheduled` | fire at specific times each day (use `scheduledTimes`) |
        | `once` | fire once at `onceDate`, then auto-disable |

        ### actionKind values
        | value | meaning |
        | --- | --- |
        | `desktop` | full-screen overlay reminder |
        | `script` | run `shellCommand` via `/bin/sh -c`; optional `logDirectoryPath` for file logs |

        ### Available themeIds
        `red-alarm` · `blue-calm` · `green-fresh` · `mono-minimal` · `gentle` · `pink` · `macaron` · `frosted`
        *(Use `curl http://127.0.0.1:18879/reminders` to see themes in use.)*

        ### Notes
        - New rules start counting from creation time; first fire happens after the full interval.
        - Overlay dismiss: close button appears after `durationSeconds`; ESC key also dismisses when closeable.
        - `canCloseImmediately: true` → close button shown immediately (durationSeconds ignored).

        ---

        > Auto-generated by Magicer · Synced: \(iso.string(from: Date()))
        """

        return s
    }

    // MARK: - Claude section content

    private static func buildClaudeSection(rules: [ReminderRule]) -> String {
        let iso = ISO8601DateFormatter()
        var s = "## Magicer 定时提醒\n\n"
        s += "> Magicer 在本机运行嵌入式 HTTP Server，AI 可通过以下 API 直接操作提醒规则。\n\n"
        s += "**Base URL**: `http://127.0.0.1:18879`\n\n"
        s += "### 当前规则\n\n"

        if rules.isEmpty {
            s += "_暂无规则_\n\n"
        } else {
            for r in rules {
                let status = r.isEnabled ? "✅" : "⏸"
                let kind = r.actionKind == .script ? "脚本" : "桌面"
                s += "- \(status) **\(r.name)** (`\(r.id)`) · \(kind)"
                switch r.triggerMode {
                case .interval:  s += " — 每 \(r.intervalMinutes) 分钟"
                case .scheduled:
                    let times = r.scheduledTimes.map { $0.displayText }.joined(separator: ", ")
                    s += " — 每天 \(times.isEmpty ? "(未设时刻)" : times)"
                case .once:      s += " — 一次 @ \(iso.string(from: r.onceDate))"
                }
                s += "\n"
            }
            s += "\n"
        }

        s += "### 操作接口\n\n"
        s += "```bash\n"
        s += "# 查询所有规则\n"
        s += "curl http://127.0.0.1:18879/reminders\n\n"
        s += "# 新增规则\n"
        s += "curl -X POST http://127.0.0.1:18879/reminders -H 'Content-Type: application/json' -d '{...}'\n\n"
        s += "# 启用/禁用\n"
        s += "curl -X PUT http://127.0.0.1:18879/reminders/{id}/toggle\n\n"
        s += "# 删除\n"
        s += "curl -X DELETE http://127.0.0.1:18879/reminders/{id}\n"
        s += "```\n\n"
        s += "> triggerMode: `interval`(循环) / `scheduled`(定点) / `once`(一次)\n"
        s += "> actionKind: `desktop`(桌面蒙层) / `script`(定时 Shell，`shellCommand` + 可选 `logDirectoryPath`)\n"
        s += "> themeId: `red-alarm` · `blue-calm` · `green-fresh` · `mono-minimal` · `gentle` · `pink` · `macaron` · `frosted`\n\n"
        s += "_Auto-synced by Magicer · \(iso.string(from: Date()))_\n"
        return s
    }
}
