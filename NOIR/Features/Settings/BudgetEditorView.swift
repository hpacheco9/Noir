//
//  BudgetEditorView.swift
//  NOIR
//

import SwiftUI

struct BudgetEditorView: View {
    @AppStorage(OnboardingStorage.monthlyBudgetKey) private var budget = OnboardingStorage.defaultMonthlyBudget
    @State private var publishTask: Task<Void, Never>?

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
        .onChange(of: budget) {
            publishTask?.cancel()
            publishTask = Task {
                try? await Task.sleep(for: .milliseconds(500))
                guard !Task.isCancelled else { return }
                await WidgetSnapshotPublisher.publish()
            }
        }
    }
}

#Preview {
    NavigationStack {
        BudgetEditorView()
    }
}
