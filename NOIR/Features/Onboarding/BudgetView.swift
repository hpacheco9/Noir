//
//  BudgetView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/08/2026.
//

import SwiftUI

struct BudgetView: View {
    @Binding var budget: Double
    @State private var isAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 80) {
            VStack(alignment: .leading, spacing: 12) {
                Text(L10n.Onboarding.budgetTitle)
                    .font(.system(size: 36, weight: .bold))

                Text(L10n.Onboarding.budgetSubtitle)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            
            Spacer()

            BudgetPickerView(budget: $budget)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isAppeared ? 1 : 0)
        .offset(y: isAppeared ? 0 : 15)
        .animation(.easeOut(duration: 0.6), value: isAppeared)
        .onAppear {
            isAppeared = true
        }
    }
}

#Preview {
    BudgetView(budget: .constant(1000))
}
