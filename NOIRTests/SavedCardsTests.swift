//
//  SavedCardsTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// In-memory store, rows inserted straight into a `ModelContext`: `repository.save` would write the overview memo
/// to `UserDefaults.standard`.
struct SavedCardsTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    /// Rows created one second apart in `cards` order, so "first seen" is the first in the list.
    private func insert(_ cards: [String], into container: ModelContainer) throws {
        let context = ModelContext(container)
        let start = Date(timeIntervalSince1970: 1_000_000)
        for (offset, card) in cards.enumerated() {
            context.insert(Expense(
                amount: 1, name: "row \(offset)", date: start, category: .other, card: card,
                createdAt: start.addingTimeInterval(TimeInterval(offset))
            ))
        }
        try context.save()
    }

    /// Runs `body` with remembered cards in a throwaway suite, never `.standard`.
    private func withIsolatedCards<T>(_ body: () async throws -> T) async rethrows -> T {
        let suite = "NOIRTests.savedCards.\(UUID().uuidString)"
        defer { UserDefaults().removePersistentDomain(forName: suite) }
        return try await SavedCards.$suiteName.withValue(suite) { try await body() }
    }

    @Test func mostUsedFirstThenByName() {
        let cards = SavedCards.make(from: ["Visa", "Amex", "Revolut", "Visa", "Amex", "Visa", "Banco"])
        #expect(cards == ["Visa", "Amex", "Banco", "Revolut"])
    }

    @Test func namesAreTrimmedAndMatchedExactly() {
        let cards = SavedCards.make(from: [" Visa ", "visa", "Visa\n", "Cartão", "Cartao"])
        #expect(cards == ["Visa", "Cartao", "Cartão", "visa"])
    }

    @Test func emptyAndWhitespaceNamesAreExcluded() {
        #expect(SavedCards.make(from: ["", "   ", "\n\t"]).isEmpty)
        #expect(SavedCards.make(from: ["", " Amex ", "  "]) == ["Amex"])
    }

    @Test func rememberedCardsStayAfterTheUsedOnes() {
        let cards = SavedCards.make(from: ["Visa", "Amex", "Visa"], remembered: ["Revolut", " Amex ", "Banco"])
        #expect(cards == ["Visa", "Amex", "Banco", "Revolut"])
    }

    @Test func fetchCardsReadsTheStore() async throws {
        try await withIsolatedCards {
            let container = try makeContainer()
            try insert(["Amex", "Visa", "", "Amex", " Visa", "  ", "Revolut", "Amex"], into: container)

            let cards = try await ExpenseRepository(modelContainer: container).fetchCards()
            #expect(cards == ["Amex", "Visa", "Revolut"])
        }
    }

    @Test func fetchCardsWithoutCardsIsEmpty() async throws {
        try await withIsolatedCards {
            let container = try makeContainer()
            try insert(["", " "], into: container)

            #expect(try await ExpenseRepository(modelContainer: container).fetchCards().isEmpty)
        }
    }

    @Test func rememberIgnoresBlanksAndDuplicates() async throws {
        try await withIsolatedCards {
            SavedCards.remember(" Visa ")
            SavedCards.remember("Visa")
            SavedCards.remember("  ")
            SavedCards.remember("Amex")
            let container = try makeContainer()
            #expect(try await ExpenseRepository(modelContainer: container).fetchCards() == ["Amex", "Visa"])
        }
    }

    @MainActor
    @Test func addPreselectsTheMostUsedCard() async throws {
        try await withIsolatedCards {
            let container = try makeContainer()
            try insert(["Visa", "Amex", "Amex"], into: container)

            let viewModel = ExpenseViewModel(model: container)
            await viewModel.loadCards()
            #expect(viewModel.form.card == "Amex")
        }
    }

    @MainActor
    @Test func addWithoutSavedCardsKeepsNoCard() async throws {
        try await withIsolatedCards {
            let viewModel = ExpenseViewModel(model: try makeContainer())
            await viewModel.loadCards()
            #expect(viewModel.form.card.isEmpty)
        }
    }

    @Test func typedNoCardIsTheNoCardChoice() async throws {
        let title = String(localized: ExpenseCardEntity.noCardTitle)
        let found = try await ExpenseCardQuery().entities(matching: "  \(title.uppercased()) ")
        #expect(found.map(\.id) == [ExpenseCardEntity.noCardID])
        #expect(found.first?.name == "")
        #expect(!ExpenseCardQuery.isNoCard("Visa"))
    }
}

extension CategoryBreakdownRepositoryTests {
    /// Writes through `repository.save` with memos in an isolated suite. Nested in the serialized suite because
    /// saves move the memo generation it checks.
    @Suite
    struct CardSaveTests {
        @Test func saveStoresAndUpdatesTheCard() async throws {
            let container = try ModelContainer(
                for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
            let suite = "NOIRTests.cards.\(UUID().uuidString)"
            defer { UserDefaults().removePersistentDomain(forName: suite) }

            try await OverviewMemoStore.$suiteName.withValue(suite) { try await SavedCards.$suiteName.withValue(suite) {
                let repository = ExpenseRepository(modelContainer: container)
                try await repository.save(
                    id: nil, amount: 5, name: "Lunch", date: .now,
                    categoryKey: ExpenseCategory.food.rawValue, description: "", card: "Visa"
                )
                let id = try #require(try ModelContext(container).fetch(FetchDescriptor<Expense>()).first?.persistentModelID)
                #expect(try await repository.fetchCards() == ["Visa"])

                try await repository.save(
                    id: id, amount: 5, name: "Lunch", date: .now,
                    categoryKey: ExpenseCategory.food.rawValue, description: "", card: "Amex"
                )
                // Visa no longer has an expense but stays saved, after the used Amex.
                #expect(try await repository.fetchCards() == ["Amex", "Visa"])
                let page = try await repository.fetchPage(query: "", offset: 0, limit: 10)
                #expect(page.map(\.card) == ["Amex"])
            } }
        }
    }
}
