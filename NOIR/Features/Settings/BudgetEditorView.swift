//
//  BudgetEditorView.swift
//  NOIR
//

import SwiftUI

/// Settings → Profile → Monthly budget. Edits the stored budget live; the widget is refreshed once on leaving.
struct BudgetEditorView: View {
    @AppStorage(OnboardingStorage.monthlyBudgetKey) private var budget = OnboardingStorage.defaultMonthlyBudget
    @State private var budgetOnAppear: Double?

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            BudgetPickerView(budget: $budget)

            Text(L10n.Profile.budgetFooter)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .navigationTitle(Text(L10n.Profile.budget))
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { budgetOnAppear = budget }
        .onDisappear {
            guard budgetOnAppear != budget else { return }
            Task { await WidgetSnapshotPublisher.publish() }
        }
    }
}

#Preview {
    NavigationStack {
        BudgetEditorView()
    }
}
