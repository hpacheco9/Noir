//
//  CategoryFormViewModelTests.swift
//  NOIRTests
//

import Testing
import SwiftData
@testable import NOIR

/// Runs against an in-memory store, so nothing touches the app's data.
struct CategoryFormViewModelTests {
    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }

    private func makeViewModel(_ container: ModelContainer) -> CategoryFormViewModel {
        CategoryFormViewModel(editing: nil, repository: .init(container: container))
    }

    @Test func emptyNameIsSkipped() async throws {
        let viewModel = makeViewModel(try makeContainer())
        viewModel.name = "   "
        #expect(await viewModel.save() == .skipped)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func validNameIsSaved() async throws {
        let viewModel = makeViewModel(try makeContainer())
        viewModel.name = "Pets"
        #expect(await viewModel.save() == .saved)
        #expect(viewModel.errorMessage == nil)
    }

    @Test func duplicateNameFailsWithMessage() async throws {
        let container = try makeContainer()
        let first = makeViewModel(container)
        first.name = "Pets"
        #expect(await first.save() == .saved)

        // A second form that hasn't loaded the existing names, so only the repository catches the duplicate.
        let second = makeViewModel(container)
        second.name = "pets"
        #expect(await second.save() == .failed)
        #expect(second.errorMessage != nil)
    }

    @Test func staleErrorDoesNotTurnASkippedSaveIntoAFailure() async throws {
        let container = try makeContainer()
        let first = makeViewModel(container)
        first.name = "Pets"
        _ = await first.save()

        let viewModel = makeViewModel(container)
        viewModel.name = "Pets"
        #expect(await viewModel.save() == .failed)
        #expect(viewModel.errorMessage != nil)

        // Name cleared without `nameDidChange()`, so the old message is still there.
        viewModel.name = ""
        #expect(await viewModel.save() == .skipped)
    }

    @Test func successfulRetryClearsPreviousError() async throws {
        let container = try makeContainer()
        let first = makeViewModel(container)
        first.name = "Pets"
        _ = await first.save()

        let viewModel = makeViewModel(container)
        viewModel.name = "Pets"
        #expect(await viewModel.save() == .failed)
        viewModel.name = "Garden"
        #expect(await viewModel.save() == .saved)
        #expect(viewModel.errorMessage == nil)
    }
}
