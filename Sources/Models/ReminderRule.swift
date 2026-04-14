import Foundation

// MARK: - Trigger Mode

enum TriggerMode: String, Codable {
    case interval  = "interval"   // 循环：每 X 分钟
    case scheduled = "scheduled"  // 定点：每天指定时刻
    case once      = "once"       // 一次：指定时刻触发一次后自动停用
}

// MARK: - Scheduled Time

struct ScheduledTime: Codable, Identifiable, Equatable {
    var id: UUID
    var hour: Int
    var minute: Int

    init(id: UUID = UUID(), hour: Int, minute: Int) {
        self.id = id
        self.hour = hour
        self.minute = minute
    }

    var displayText: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

// MARK: - ReminderRule

struct ReminderRule: Codable, Identifiable, Equatable {
    var id: UUID
    var name: String
    var triggerMode: TriggerMode
    var intervalMinutes: Int
    var scheduledTimes: [ScheduledTime]
    /// Target datetime for `.once` mode — triggers once then auto-disables.
    var onceDate: Date
    /// After the overlay is dismissed, trigger again after this many minutes (0 = no followup).
    var followupMinutes: Int
    var durationSeconds: Int
    var canCloseImmediately: Bool
    var reminderText: String
    var themeId: String
    var isEnabled: Bool

    // Custom CodingKeys and decoder to maintain backward compatibility.
    // New fields (onceDate, followupMinutes) fall back to defaults when absent in stored data.
    private enum CodingKeys: String, CodingKey {
        case id, name, triggerMode, intervalMinutes, scheduledTimes
        case onceDate, followupMinutes
        case durationSeconds, canCloseImmediately, reminderText, themeId, isEnabled
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id               = try c.decode(UUID.self,            forKey: .id)
        name             = try c.decode(String.self,          forKey: .name)
        triggerMode      = (try? c.decode(TriggerMode.self,   forKey: .triggerMode)) ?? .interval
        intervalMinutes  = try c.decode(Int.self,             forKey: .intervalMinutes)
        scheduledTimes   = try c.decode([ScheduledTime].self, forKey: .scheduledTimes)
        onceDate         = (try? c.decode(Date.self,          forKey: .onceDate)) ?? Date().addingTimeInterval(3600)
        followupMinutes  = (try? c.decode(Int.self,           forKey: .followupMinutes)) ?? 0
        durationSeconds  = try c.decode(Int.self,             forKey: .durationSeconds)
        canCloseImmediately = try c.decode(Bool.self,         forKey: .canCloseImmediately)
        reminderText     = try c.decode(String.self,          forKey: .reminderText)
        themeId          = try c.decode(String.self,          forKey: .themeId)
        isEnabled        = try c.decode(Bool.self,            forKey: .isEnabled)
    }

    init(
        id: UUID = UUID(),
        name: String = "提醒",
        triggerMode: TriggerMode = .interval,
        intervalMinutes: Int = 60,
        scheduledTimes: [ScheduledTime] = [],
        onceDate: Date = Date().addingTimeInterval(3600),
        followupMinutes: Int = 0,
        durationSeconds: Int = 10,
        canCloseImmediately: Bool = false,
        reminderText: String = "该休息了，离开屏幕活动一下。",
        themeId: String = "red-alarm",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.triggerMode = triggerMode
        self.intervalMinutes = intervalMinutes
        self.scheduledTimes = scheduledTimes
        self.onceDate = onceDate
        self.followupMinutes = followupMinutes
        self.durationSeconds = durationSeconds
        self.canCloseImmediately = canCloseImmediately
        self.reminderText = reminderText
        self.themeId = themeId
        self.isEnabled = isEnabled
    }
}
