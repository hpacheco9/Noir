//
//  FirstExpenseViews.swift
//  NOIR
//

import SwiftUI

struct FirstExpenseNameView: View {
    @Binding var name: String

    var body: some View {
        FirstExpenseStepContainer(
            step: 1,
            title: "Add your first expense.",
            subtitle: "What did you spend money on?"
        ) {
            TextField("For example, coffee", text: $name)
                .textInputAutocapitalization(.sentences)
                .font(.title2.weight(.medium))
                .padding()
                .background(.thinMaterial, in: .rect(cornerRadius: 18))
        }
    }
}

struct FirstExpenseAmountView: View {
    @Binding var amount: Decimal
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    private var currencyFormat: AmountInputFormatStyle {
        CurrencyPreference.amountInputStyle(for: currencyCode)
    }

    var body: some View {
        FirstExpenseStepContainer(
            step: 2,
            title: "How much was it?",
            subtitle: "Add the amount you paid."
        ) {
            TextField("0.00", value: $amount, format: currencyFormat)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.center)
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .padding()
                .accessibilityLabel("Expense amount")
        }
    }
}

struct FirstExpenseCategoryView: View {
    @Binding var category: ExpenseCategory

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        FirstExpenseStepContainer(
            step: 3,
            title: "Choose a category.",
            subtitle: "You can change this later."
        ) {
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(ExpenseCategory.allCases) { option in
                    ExpenseCategoryOption(
                        category: option,
                        isSelected: category == option,
                        select: { category = option }
                    )
                }
            }
        }
    }
}

private struct ExpenseCategoryOption: View {
    let category: ExpenseCategory
    let isSelected: Bool
    let select: () -> Void

    var body: some View {
        Button(action: select) {
            Label(category.title, systemImage: category.icon)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .foregroundStyle(isSelected ? Color(uiColor: .systemBackground) : .primary)
                .background {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(isSelected ? AnyShapeStyle(category.color) : AnyShapeStyle(.thinMaterial))
                }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct FirstExpenseStepContainer<Content: View>: View {
    let step: Int
    let title: String
    let subtitle: String?
    @ViewBuilder let content: Content
    @State private var isAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("FIRST EXPENSE · \(step) OF 3")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(.system(size: 34, weight: .bold))

                if let subtitle {
                    Text(subtitle)
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
            }

            content
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
    FirstExpenseCategoryView(category: .constant(.food))
        .padding()
}
