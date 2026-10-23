//
//  BudgetSummaryView.swift
//  NOIR
//

import SwiftUI

struct BudgetSummaryView: View {
    let monthTotal: Decimal
    let currencyCode: String

    @AppStorage(OnboardingStorage.monthlyBudgetKey) private var budget = 0.0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        if let progress = BudgetProgress(total: monthTotal, budget: budget) {
            VStack(alignment: .leading, spacing: 8) {
                Text(message(for: progress))
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(progress.isOver ? Color.trendWorse : Color.secondary)

                ProgressView(value: progress.fraction)
                    .tint(progress.isOver ? Color.trendWorse : Color.primary)
                    .animation(reduceMotion ? nil : .smooth, value: progress.fraction)
                    .accessibilityHidden(true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityElement(children: .combine)
        }
    }

    private func message(for progress: BudgetProgress) -> LocalizedStringResource {
        if progress.isOver {
            return L10n.BudgetSummary.over(whole(progress.wholeOver.doubleValue))
        }
        return L10n.BudgetSummary.left(whole(progress.wholeLeft.doubleValue), of: whole(budget))
    }

    private func whole(_ amount: Double) -> String {
        CurrencyPreference.wholeString(for: amount, code: currencyCode)
    }
}
