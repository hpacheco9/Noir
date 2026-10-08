//
//  Repository.swift
//  NOIR
//
//  Created by Henrique Pacheco on 27/07/2026.
//

import Foundation
import SwiftData

enum RepositoryError: Error {
       case notFound
}

@ModelActor
actor ExpenseRepository {
    
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
                latitude: latitude,
                longitude: longitude,
                locationName: locationName
            )
            modelContext.insert(expense)
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
