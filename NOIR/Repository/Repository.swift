//
//  Repository.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation
import SwiftData

@ModelActor
actor ExpenseRepository {
    enum RepositoryError: Error {
           case notFound
    }
    
    func fetch() throws -> [ExpenseDTO] {
        let descriptor = FetchDescriptor<Expense>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        return try modelContext.fetch(descriptor).map(ExpenseDTO.init)
    }

    func fetchPage(query: String, offset: Int, limit: Int) throws -> [ExpenseDTO] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let predicate: Predicate<Expense>?

        if normalizedQuery.isEmpty {
            predicate = nil
        } else {
            predicate = #Predicate<Expense> { expense in
                expense.name.localizedStandardContains(normalizedQuery)
            }
        }

        var descriptor = FetchDescriptor<Expense>(
            predicate: predicate,
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = limit
        descriptor.fetchOffset = offset
        return try modelContext.fetch(descriptor).map(ExpenseDTO.init)
    }

    func save(
        id: PersistentIdentifier?,
        amount: Double,
        name: String,
        date: Date,
        category: ExpenseCategory,
        description: String,
        isRecurring: Bool,
        recurrenceDay: Int,
        latitude: Double?,
        longitude: Double?,
        locationName: String?
    ) throws {
        if let id {
            guard let expense = modelContext.model(for: id) as? Expense else {
                throw RepositoryError.notFound
            }

            expense.amount = amount
            expense.name = name
            expense.date = date
            expense.category = category
            expense.expenseDescription = description
            expense.isRecurring = isRecurring
            expense.recurrenceDay = recurrenceDay
            if expense.recurrenceSeriesID == nil {
                expense.recurrenceSeriesID = UUID()
            }
            expense.isRecurrenceTemplate = true
            expense.latitude = latitude
            expense.longitude = longitude
            expense.locationName = locationName
        } else {
            let expense = Expense(
                amount: amount,
                name: name,
                date: date,
                category: category,
                expenseDescription: description,
                isRecurring: isRecurring,
                recurrenceDay: recurrenceDay,
                recurrenceSeriesID: isRecurring ? UUID() : nil,
                isRecurrenceTemplate: isRecurring,
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            )
            modelContext.insert(expense)
        }

        try modelContext.save()
    }

    func synchronizeRecurringExpenses(now: Date = .now, calendar: Calendar = .current) throws {
        let expenses = try modelContext.fetch(FetchDescriptor<Expense>())
        let templates = expenses.filter { $0.isRecurring && $0.isRecurrenceTemplate }

        for template in templates {
            guard let seriesID = template.recurrenceSeriesID else { continue }
            let startComponents = calendar.dateComponents([.year, .month], from: template.date)
            let currentComponents = calendar.dateComponents([.year, .month], from: now)
            guard let startMonth = calendar.date(from: startComponents),
                  let currentMonth = calendar.date(from: currentComponents) else { continue }

            var month = calendar.date(byAdding: .month, value: 1, to: startMonth) ?? currentMonth
            while month <= currentMonth {
                let monthComponents = calendar.dateComponents([.year, .month], from: month)
                guard let year = monthComponents.year, let monthNumber = monthComponents.month else { break }
                let key = "\(seriesID.uuidString)-\(year)-\(monthNumber)"

                if !expenses.contains(where: { $0.recurrenceOccurrenceKey == key }) {
                    let daysInMonth = calendar.range(of: .day, in: .month, for: month)?.count ?? 28
                    let day = min(template.recurrenceDay, daysInMonth)
                    let occurrenceDate = calendar.date(bySetting: .day, value: day, of: month) ?? month
                    let occurrence = Expense(
                        amount: template.amount,
                        name: template.name,
                        date: occurrenceDate,
                        category: template.category,
                        expenseDescription: template.expenseDescription,
                        isRecurring: false,
                        recurrenceDay: template.recurrenceDay,
                        recurrenceSeriesID: seriesID,
                        isRecurrenceTemplate: false,
                        recurrenceOccurrenceKey: key,
                        latitude: template.latitude,
                        longitude: template.longitude,
                        locationName: template.locationName
                    )
                    modelContext.insert(occurrence)
                }

                guard let nextMonth = calendar.date(byAdding: .month, value: 1, to: month) else { break }
                month = nextMonth
            }
        }

        try modelContext.save()
    }
    
    func delete(id: PersistentIdentifier) throws {
          guard let expense = modelContext.model(for: id) as? Expense else {
              throw RepositoryError.notFound
          }
          modelContext.delete(expense)
          try modelContext.save()
      }
}
