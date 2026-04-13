import Foundation

class RuleTimerManager {
    static let shared = RuleTimerManager()

    private var timers: [UUID: Timer] = [:]

    private init() {}

    func start() {
        reload(rules: RulesStore.shared.rules)
    }

    func reload(rules: [ReminderRule]) {
        timers.values.forEach { $0.invalidate() }
        timers.removeAll()

        for rule in rules where rule.isEnabled {
            schedule(rule: rule)
        }
    }

    private func schedule(rule: ReminderRule) {
        switch rule.triggerMode {
        case .interval:
            scheduleInterval(rule: rule)
        case .scheduled:
            scheduleNextFixed(rule: rule)
        }
    }

    // MARK: - Interval Mode

    private func scheduleInterval(rule: ReminderRule) {
        let interval = TimeInterval(max(1, rule.intervalMinutes) * 60)
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            self?.fire(rule: rule)
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[rule.id] = timer
    }

    // MARK: - Scheduled (Fixed Time) Mode

    private func scheduleNextFixed(rule: ReminderRule) {
        guard !rule.scheduledTimes.isEmpty else { return }

        guard let nextDate = nextScheduledDate(for: rule) else { return }
        let interval = max(1, nextDate.timeIntervalSinceNow)

        let timer = Timer(timeInterval: interval, repeats: false) { [weak self] _ in
            self?.fire(rule: rule)
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                self?.scheduleNextFixed(rule: rule)
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[rule.id] = timer
    }

    func nextScheduledDate(for rule: ReminderRule) -> Date? {
        guard rule.triggerMode == .scheduled, !rule.scheduledTimes.isEmpty else { return nil }

        let now = Date()
        let calendar = Calendar.current
        var candidates: [Date] = []

        for t in rule.scheduledTimes {
            var comps = calendar.dateComponents([.year, .month, .day], from: now)
            comps.hour = t.hour
            comps.minute = t.minute
            comps.second = 0

            if let date = calendar.date(from: comps) {
                if date > now.addingTimeInterval(5) {
                    candidates.append(date)
                } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
                    candidates.append(tomorrow)
                }
            }
        }

        return candidates.min()
    }

    // MARK: - Fire

    private func fire(rule: ReminderRule) {
        DispatchQueue.main.async {
            OverlayManager.show(rule: rule)
        }
    }

    // MARK: - Queries

    func nextFireDate(for ruleId: UUID) -> Date? {
        return timers[ruleId]?.fireDate
    }

    func isActive(for ruleId: UUID) -> Bool {
        return timers[ruleId] != nil
    }
}
