import Foundation

class RuleTimerManager {
    static let shared = RuleTimerManager()

    private var timers: [UUID: Timer] = [:]

    // UserDefaults key prefix for persisting last fire time per rule
    private static let lastFireKeyPrefix = "magicer_last_fire_"

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
        case .once:
            scheduleOnce(rule: rule)
        }
    }

    // MARK: - Interval Mode

    private func lastFireKey(for rule: ReminderRule) -> String {
        "\(RuleTimerManager.lastFireKeyPrefix)\(rule.id.uuidString)"
    }

    private func saveLastFire(for rule: ReminderRule) {
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: lastFireKey(for: rule))
    }

    private func scheduleInterval(rule: ReminderRule) {
        let interval = TimeInterval(max(1, rule.intervalMinutes) * 60)

        // Calculate how long until the NEXT fire, accounting for time elapsed since last fire
        let key = lastFireKey(for: rule)
        let now = Date().timeIntervalSince1970
        let lastFire = UserDefaults.standard.double(forKey: key) // 0 if never saved
        let elapsed = lastFire > 0 ? now - lastFire : interval  // treat as full cycle if no history
        let remaining = max(1, interval - elapsed)

        // One-shot timer for the first fire (with remaining delay), then switch to repeating
        let initialTimer = Timer(timeInterval: remaining, repeats: false) { [weak self] _ in
            guard let self else { return }
            self.fire(rule: rule)
            // Start repeating timer after initial fire
            let repeating = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
                self?.fire(rule: rule)
            }
            RunLoop.main.add(repeating, forMode: .common)
            self.timers[rule.id] = repeating
        }
        RunLoop.main.add(initialTimer, forMode: .common)
        timers[rule.id] = initialTimer
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

    // MARK: - One-shot Mode

    private func scheduleOnce(rule: ReminderRule) {
        let delay = rule.onceDate.timeIntervalSinceNow
        guard delay > 0 else {
            // Date already passed — auto-disable without firing
            DispatchQueue.main.async {
                var updated = rule
                updated.isEnabled = false
                RulesStore.shared.updateRule(updated)
            }
            return
        }
        let timer = Timer(timeInterval: delay, repeats: false) { [weak self] _ in
            self?.fire(rule: rule)
            var updated = rule
            updated.isEnabled = false
            RulesStore.shared.updateRule(updated)
        }
        RunLoop.main.add(timer, forMode: .common)
        timers[rule.id] = timer
    }

    // MARK: - Fire

    private func fire(rule: ReminderRule) {
        saveLastFire(for: rule)
        DispatchQueue.main.async {
            let followup: (() -> Void)? = rule.followupMinutes > 0 ? {
                let delay = TimeInterval(rule.followupMinutes * 60)
                let t = Timer(timeInterval: delay, repeats: false) { _ in
                    DispatchQueue.main.async { OverlayManager.show(rule: rule) }
                }
                RunLoop.main.add(t, forMode: .common)
            } : nil
            OverlayManager.show(rule: rule, onDismiss: followup)
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
