//
//  ExpenseSummarySnippet.swift
//  NOIR
//

import AppIntents
import SwiftUI


struct ExpenseSummarySnippetIntent: SnippetIntent {
    static let title: LocalizedStringResource = "app_intent.summary.snippet_title"
    static let isDiscoverable = false

    @Parameter var name: String
    @Parameter var amount: Double
    @Parameter var date: Date
    @Parameter var categoryName: String


    init() {}

    init(name: String, amount: Double, categoryName: String, date: Date) {
        self.name = name
        self.amount = amount
        self.categoryName = categoryName
        self.date = date
    }

    @MainActor
    func perform() async throws -> some IntentResult & ShowsSnippetView {
        let code = UserDefaults.standard.string(forKey: CurrencyPreference.storageKey) ?? CurrencyPreference.defaultCode
        return .result(
            view: ExpenseSummaryView(
                amount: CurrencyPreference.string(for: amount, code: code),
                name: name,
                categoryName: categoryName,
                date: date
            )
        )
    }
}

struct ExpenseSummaryView: View {
    let amount: String
    let name: String
    let categoryName: String
    let date: Date

    var body: some View {
        VStack(spacing: 24) {
            Text(amount)
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .lineLimit(1)
                .frame(maxWidth: .infinity)

            VStack(spacing: 18) {
                row(L10n.AppIntent.summaryTitle, systemImage: AssetName.System.title, value: name)
                row(L10n.AppIntent.category, systemImage: AssetName.System.categories, value: categoryName)
                row(
                    L10n.AppIntent.date,
                    systemImage: AssetName.System.calendar,
                    value: date.formatted(date: .numeric, time: .omitted)
                )
            }
        }
    }

    private func row(_ label: LocalizedStringResource, systemImage: String, value: String) -> some View {
        HStack {
            Label {
                Text(label)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.trailing)
        }
    }
}

#Preview {
    ExpenseSummaryView(amount: "12,50 €", name: "Lunch", categoryName: "Food", date: .now)
}
