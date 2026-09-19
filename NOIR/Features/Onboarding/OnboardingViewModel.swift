import Foundation
import Observation

@MainActor
@Observable
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, name, budget
    }

    var step: Step = .welcome
    var name = ""
    var motivation: String?
    var budget: Double = 1000

    var canAdvance: Bool {
        step != .name || !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var isFirstStep: Bool { step == .welcome }
    var isLastStep: Bool { step == .budget }

    func advance() {
        guard canAdvance, !isLastStep else { return }
        step = Step(rawValue: step.rawValue + 1) ?? step
    }

    func goBack() {
        guard !isFirstStep else { return }
        step = Step(rawValue: step.rawValue - 1) ?? step
    }

    func persist() {
        UserDefaults.standard.set(name.trimmingCharacters(in: .whitespacesAndNewlines), forKey: "profile.name")
        UserDefaults.standard.set(budget, forKey: "profile.monthlyBudget")
        if let motivation { UserDefaults.standard.set(motivation, forKey: "profile.motivation") }
    }
}
