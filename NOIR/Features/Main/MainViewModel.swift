//
//  MainViewModel.swift
//  NOIR
//
//  Created by Henrique Pacheco on 26/07/2026.
//

import Foundation
import SwiftData
import SwiftUI


@Observable
final class MainViewModel {
    var state: State = .loading
    let repository: ExpenseRepository
    
    enum State {
        case loading
        case loaded([ExpenseDTO])
        case empty
    }
    
    init(model: ModelContainer) {
        self.repository = .init(modelContainer: model)
    }
    
    var currencyCode: String {
        Locale.current.currency?.identifier ?? "USD"
    }

    func recentExpenseSections(from expenses: [ExpenseDTO], limit: Int = 10) -> [ExpenseDaySection] {
        let recentExpenses = expenses
            .sorted { $0.date > $1.date }
            .prefix(limit)

        let grouped = Dictionary(grouping: recentExpenses) { expense in
            Calendar.current.startOfDay(for: expense.date)
        }

        return grouped.keys.sorted(by: >).map { date in
            ExpenseDaySection(
                date: date,
                expenses: (grouped[date] ?? []).sorted { $0.date > $1.date }
            )
        }
    }

    func title(for date: Date) -> String {
        if Calendar.current.isDateInToday(date) { return "Today" }
        if Calendar.current.isDateInYesterday(date) { return "Yesterday" }
        return date.formatted(.dateTime.month(.wide).day())
    }
}

struct ExpenseDaySection: Identifiable {
    let date: Date
    let expenses: [ExpenseDTO]

    var id: Date { date }
}

extension MainViewModel{
    @MainActor
    func fetchData() async {
        do {
            try await repository.synchronizeRecurringExpenses()
            let data = try await repository.fetch()
            withAnimation(.snappy) {
                      state = data.isEmpty ? .empty : .loaded(data)
            }
        } catch {
            print("Failed to fetch expenses: \(error)")
        }
    }
    
    func delete(id: PersistentIdentifier) async {
        do {
            try await repository.delete(id: id)
            await fetchData()
        } catch {
            print(error)
        }
    }
}

struct ExpenseDTO: Sendable, Identifiable {
    let id: PersistentIdentifier
    let name: String
    let category: ExpenseCategory
    let amount: Double
    let date: Date
    let description: String
    let isRecurring: Bool
    let recurrenceDay: Int
    let recurrenceSeriesID: UUID?
    let isRecurrenceTemplate: Bool
    let latitude: Double?
    let longitude: Double?
    let locationName: String?

   
    nonisolated init(_ expense: Expense) {
        self.id = expense.persistentModelID
        self.name = expense.name
        self.category = expense.category
        self.date = expense.date
        self.amount = expense.amount
        self.description = expense.expenseDescription
        self.isRecurring = expense.isRecurring
        self.recurrenceDay = expense.recurrenceDay
        self.recurrenceSeriesID = expense.recurrenceSeriesID
        self.isRecurrenceTemplate = expense.isRecurrenceTemplate
        self.latitude = expense.latitude
        self.longitude = expense.longitude
        self.locationName = expense.locationName
    }
}

extension ExpenseDTO: Equatable {}
