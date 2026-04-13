import Foundation
import Combine

/// Observable wrapper so SwiftUI views can react to OffWorkManager state changes.
class OffWorkState: ObservableObject {
    static let shared = OffWorkState()

    @Published private(set) var isActive: Bool = false

    private init() {}

    func update(_ active: Bool) {
        DispatchQueue.main.async {
            self.isActive = active
        }
    }
}
