//
//  TrialLength.swift
//  NOIR
//

import Foundation
import RevenueCat

nonisolated enum TrialLength {
    // The app's own language, so "3 days" matches the sentence around it.
    static var appLocale: Locale {
        Bundle.main.preferredLocalizations.first.map(Locale.init(identifier:)) ?? .current
    }

    // Spoken length of an introductory offer ("3 days"), only when it is a free trial.
    static func text(for discount: StoreProductDiscount?, locale: Locale = appLocale) -> String? {
        guard let discount, discount.paymentMode == .freeTrial else { return nil }
        let count = discount.subscriptionPeriod.value * discount.numberOfPeriods
        guard count > 0 else { return nil }

        var components = DateComponents()
        switch discount.subscriptionPeriod.unit {
        case .day: components.day = count
        case .week: components.weekOfMonth = count
        case .month: components.month = count
        case .year: components.year = count
        @unknown default: return nil
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = locale
        let formatter = DateComponentsFormatter()
        formatter.calendar = calendar
        formatter.unitsStyle = .full
        formatter.allowedUnits = [.day, .weekOfMonth, .month, .year]
        formatter.maximumUnitCount = 1
        return formatter.string(from: components)
    }
}
