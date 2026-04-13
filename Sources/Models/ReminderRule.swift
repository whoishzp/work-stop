import Foundation

// MARK: - Trigger Mode

enum TriggerMode: String, Codable {
    case interval  = "interval"   // 循环：每 X 分钟
    case scheduled = "scheduled"  // 定点：每天指定时刻
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
    var durationSeconds: Int
    var canCloseImmediately: Bool
    var reminderText: String
    var themeId: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String = "提醒",
        triggerMode: TriggerMode = .interval,
        intervalMinutes: Int = 60,
        scheduledTimes: [ScheduledTime] = [],
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
        self.durationSeconds = durationSeconds
        self.canCloseImmediately = canCloseImmediately
        self.reminderText = reminderText
        self.themeId = themeId
        self.isEnabled = isEnabled
    }
}
