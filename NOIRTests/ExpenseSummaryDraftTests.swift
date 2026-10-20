//
//  ExpenseSummaryDraftTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftData
@testable import NOIR

/// A class so each test gets a throwaway suite (never the app's real defaults) that is removed in `deinit`.
final class ExpenseSummaryDraftTests {
    private let suiteName = "ExpenseSummaryDraftTests.\(UUID().uuidString)"
    private let defaults: UserDefaults

    init() {
        defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func storageKeyIsStable() {
        #expect(ExpenseSummaryDraft.storageKey == "app_intent.summary_draft")
    }

    @Test func loadWithoutDraftIsNil() {
        #expect(ExpenseSummaryDraft.load(from: defaults) == nil)
    }

    @Test func saveThenLoadRoundTrips() {
        let draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "Visa")
        draft.save(to: defaults)
        #expect(ExpenseSummaryDraft.load(from: defaults) == draft)
    }

    /// A picker change overwrites the draft the summary opened with.
    @Test func saveReplacesPreviousDraft() {
        ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "").save(to: defaults)
        let changed = ExpenseSummaryDraft(categoryKey: "health", categoryName: "Health", card: "Amex")
        changed.save(to: defaults)
        #expect(ExpenseSummaryDraft.load(from: defaults) == changed)
    }

    @Test func clearRemovesDraft() {
        ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "Visa").save(to: defaults)
        #expect(ExpenseSummaryDraft.load(from: defaults) != nil)
        ExpenseSummaryDraft.clear(from: defaults)
        #expect(ExpenseSummaryDraft.load(from: defaults) == nil)
    }

    @Test func corruptDataLoadsAsNil() {
        defaults.set(Data("not json".utf8), forKey: ExpenseSummaryDraft.storageKey)
        #expect(ExpenseSummaryDraft.load(from: defaults) == nil)
    }

    @Test func startsCollapsed() {
        let draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "")
        #expect(draft.expanded == nil)
    }

    /// Positive control for the collapse tests: toggling does open a list.
    @Test func toggleOpensThenClosesSameList() {
        var draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "")
        draft.toggle(.category)
        #expect(draft.expanded == .category)
        draft.toggle(.category)
        #expect(draft.expanded == nil)
    }

    @Test func togglingOtherListSwitchesToIt() {
        var draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "")
        draft.toggle(.category)
        draft.toggle(.card)
        #expect(draft.expanded == .card)
    }

    @Test func selectingCategorySetsItAndCollapses() {
        var draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "Visa")
        draft.toggle(.category)
        draft.selectCategory(key: "health", name: "Health")
        #expect(draft == ExpenseSummaryDraft(categoryKey: "health", categoryName: "Health", card: "Visa"))
    }

    @Test func selectingCardSetsItAndCollapses() {
        var draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "Visa")
        draft.toggle(.card)
        draft.selectCard("")
        #expect(draft == ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: ""))
    }

    @Test func updateChangesStoredDraft() {
        ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "").save(to: defaults)
        ExpenseSummaryDraft.update(in: defaults) { $0.toggle(.card) }
        #expect(ExpenseSummaryDraft.load(from: defaults)?.expanded == .card)
    }

    /// A control tapped after Save/Cancel cleared the draft must not bring it back.
    @Test func updateWithoutDraftDoesNothing() {
        ExpenseSummaryDraft.update(in: defaults) { $0.toggle(.card) }
        #expect(ExpenseSummaryDraft.load(from: defaults) == nil)
    }

    @Test func expandedListRoundTrips() {
        var draft = ExpenseSummaryDraft(categoryKey: "food", categoryName: "Food", card: "")
        draft.toggle(.category)
        draft.save(to: defaults)
        #expect(ExpenseSummaryDraft.load(from: defaults) == draft)
    }

    @Test func noCardOptionMapsBackToEmptyCard() {
        #expect(SelectSummaryCardIntent(card: "").card == ExpenseCardEntity.noCardID)
        #expect(ExpenseCardEntity(id: SelectSummaryCardIntent(card: "").card).name == "")
        #expect(ExpenseCardEntity(id: SelectSummaryCardIntent(card: "Visa").card).name == "Visa")
    }

    @Test func draftKeyOfDeletedCustomCategoryResolvesToOther() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let draft = ExpenseSummaryDraft(categoryKey: CategoryInfo.key(forCustomID: UUID()), categoryName: "Gone", card: "")
        #expect(CategoryCatalog.resolvedKey(draft.categoryKey, in: context) == ExpenseCategory.other.rawValue)
    }

    /// Positive control: an existing custom category keeps its key, so the fallback above is not the only outcome.
    @Test func draftKeyOfExistingCustomCategoryIsKept() throws {
        let container = try makeContainer()
        let context = ModelContext(container)
        let custom = CustomCategory(name: "Pets", symbol: AssetName.CategorySymbols.all[0], colorRawValue: "teal")
        context.insert(custom)
        try context.save()
        let key = CategoryInfo.key(forCustomID: custom.id)
        #expect(CategoryCatalog.resolvedKey(key, in: context) == key)
        #expect(CategoryCatalog.resolvedKey(ExpenseCategory.health.rawValue, in: context) == ExpenseCategory.health.rawValue)
    }

    private func makeContainer() throws -> ModelContainer {
        try ModelContainer(
            for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
    }
}
