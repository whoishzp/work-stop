import Foundation
import Combine

class RulesStore: ObservableObject {
    static let shared = RulesStore()

    @Published var rules: [ReminderRule] {
        didSet {
            save()
            RuleTimerManager.shared.reload(rules: rules)
        }
    }

    private let key = "work_stop_rules_v1"

    private init() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([ReminderRule].self, from: data) {
            rules = decoded
        } else {
            rules = [ReminderRule(name: "专注提醒")]
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: key)
        }
        ReminderSkillExporter.export(rules: rules)
    }

    func addRule() {
        rules.append(ReminderRule(name: "提醒 \(rules.count + 1)"))
    }

    func updateRule(_ rule: ReminderRule) {
        if let idx = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[idx] = rule
        }
    }

    func deleteRules(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
    }
}
