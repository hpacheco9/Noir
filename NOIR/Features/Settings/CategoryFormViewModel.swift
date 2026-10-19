//
//  CategoryFormViewModel.swift
//  NOIR
//

import Foundation
import Observation
import SwiftUI

@MainActor
@Observable
final class CategoryFormViewModel {
    static let maxNameLength = 24

    var name = ""
    var symbol = AssetName.CategorySymbols.all[0]
    /// `nil` when an edited category has a stored colour outside the palette (rows show it gray); it stays that way
    /// until the user picks one.
    var color: CategoryColor? = CategoryColor.allCases[0]
    private(set) var errorMessage: String?
    /// Shown in an alert (not in the name footer).
    var deleteErrorMessage: String?
    /// Titles already taken (built-in and custom) by key, loaded by `loadExistingNames()`.
    private var existing: [(key: String, title: String)] = ExpenseCategory.allCases.map { ($0.rawValue, $0.title) }
    /// The custom category being edited; `nil` when creating.
    private var editingCategory: CategoryInfo?
    private(set) var isEditing = false
    /// A save or delete is in flight.
    private(set) var isWorking = false

    private let repository: ExpenseRepositoryProvider

    /// `editing`: a custom category to edit, `nil` to create. Configuring here (not in `.task`) means the sheet's
    /// first frame already shows the right state.
    init(editing category: CategoryInfo? = nil, repository: ExpenseRepositoryProvider? = nil) {
        self.repository = repository ?? .init(container: NOIRApp.sharedModelContainer)
        configure(with: category)
    }

    var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }

    var displayColor: Color { color?.color ?? .gray }

    /// The typed name matches an existing title (case- and accent-insensitive). The repository re-checks on save.
    /// Editing: the category's own stored name never counts, even if a built-in title now matches it.
    var isDuplicate: Bool {
        let name = trimmedName
        guard !name.isEmpty else { return false }
        func matches(_ title: String) -> Bool {
            title.compare(name, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let own = editingCategory?.customName, matches(own) { return false }
        return existing.contains { $0.key != editingCategory?.key && matches($0.title) }
    }

    /// Always true when creating; when editing, only once name, symbol or colour differ from what was stored.
    private var hasChanges: Bool {
        guard let editingCategory else { return true }
        return trimmedName != editingCategory.title
            || symbol != editingCategory.icon
            || color != CategoryColor(rawValue: editingCategory.colorRawValue)
    }

    var canSave: Bool { !trimmedName.isEmpty && !isDuplicate && !isWorking && hasChanges }

    /// What to show under the name field: the live duplicate warning, else the last save error.
    var visibleMessage: String? {
        isDuplicate ? String(localized: L10n.NewCategory.duplicateError) : errorMessage
    }

    func loadExistingNames() async {
        guard let all = try? await repository.perform({ try await $0.fetchCategories() }) else { return }
        existing = all.map { ($0.key, $0.title) }
    }

    /// `nil` for create, a category (custom or built-in) for edit; prefills its current name, symbol and colour.
    func configure(with category: CategoryInfo?) {
        guard let category else {
            reset()
            return
        }
        editingCategory = category
        isEditing = true
        name = category.title
        symbol = category.icon
        color = CategoryColor(rawValue: category.colorRawValue)
        errorMessage = nil
        deleteErrorMessage = nil
    }

    /// Back to the create defaults.
    func reset() {
        editingCategory = nil
        isEditing = false
        name = ""
        symbol = AssetName.CategorySymbols.all[0]
        color = CategoryColor.allCases[0]
        errorMessage = nil
        deleteErrorMessage = nil
    }

    /// Custom categories can be deleted; built-ins can't (Other is the fallback for deleted ones).
    var canDelete: Bool { editingCategory.map { !$0.isBuiltIn } ?? false }
    /// A built-in that has an override can go back to its defaults.
    var canRestore: Bool { editingCategory.map { $0.isBuiltIn && $0.isOverridden } ?? false }

    /// Removes a built-in's override. Returns whether it was restored.
    func restoreDefault() async -> Bool {
        guard let key = editingCategory?.key, canRestore, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let reserved = Dictionary(uniqueKeysWithValues: ExpenseCategory.allCases.map { ($0.rawValue, $0.title) })
            _ = try await repository.perform { try await $0.restoreBuiltInCategory(key: key, reservedNames: reserved) }
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            NotificationCenter.default.post(name: .expensesDidChange, object: nil)
            return true
        } catch CategoryError.duplicateName {
            errorMessage = String(localized: L10n.NewCategory.restoreDuplicateError)
            return false
        } catch {
            errorMessage = String(localized: L10n.NewCategory.saveError)
            return false
        }
    }

    var title: LocalizedStringResource { isEditing ? L10n.NewCategory.editTitle : L10n.NewCategory.title }

    /// Deletes the edited category (its expenses move to Other). Returns whether it was deleted.
    func delete() async -> Bool {
        guard let id = editingCategory?.customID, !isWorking else { return false }
        isWorking = true
        defer { isWorking = false }
        do {
            let reassigned = try await repository.perform { try await $0.deleteCategory(id: id) }
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            if reassigned > 0 { NotificationCenter.default.post(name: .expensesDidChange, object: nil) }
            return true
        } catch {
            deleteErrorMessage = String(localized: L10n.Categories.deleteError)
            return false
        }
    }

    /// Clears a stale duplicate error as soon as the user edits the name.
    func nameDidChange() {
        if name.count > Self.maxNameLength { name = String(name.prefix(Self.maxNameLength)) }
        errorMessage = nil
    }

    /// Creates or updates the category and posts the change notifications. Returns whether it was saved.
    func save() async -> Bool {
        guard canSave else { return false }
        isWorking = true
        defer { isWorking = false }

        let name = trimmedName
        let symbol = symbol
        let color = color
        let reserved = Dictionary(uniqueKeysWithValues: ExpenseCategory.allCases.map { ($0.rawValue, $0.title) })
        do {
            if let editing = editingCategory, editing.isBuiltIn {
                let key = editing.key
                _ = try await repository.perform {
                    try await $0.updateBuiltInCategory(
                        key: key, name: name, symbol: symbol,
                        color: color ?? CategoryColor.allCases[0], reservedNames: reserved
                    )
                }
                NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
                NotificationCenter.default.post(name: .expensesDidChange, object: nil)
                return true
            }
            if let id = editingCategory?.customID {
                _ = try await repository.perform {
                    try await $0.updateCategory(id: id, name: name, symbol: symbol, color: color, reservedNames: reserved)
                }
                // Home and Search rows show the category's name, icon and colour.
                NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
                NotificationCenter.default.post(name: .expensesDidChange, object: nil)
                return true
            }
            _ = try await repository.perform {
                try await $0.createCategory(name: name, symbol: symbol, color: color ?? CategoryColor.allCases[0], reservedNames: reserved)
            }
            NotificationCenter.default.post(name: .categoriesDidChange, object: nil)
            return true
        } catch CategoryError.duplicateName {
            errorMessage = String(localized: L10n.NewCategory.duplicateError)
        } catch CategoryError.emptyName {
            errorMessage = String(localized: L10n.NewCategory.emptyError)
        } catch {
            errorMessage = String(localized: L10n.NewCategory.saveError)
        }
        return false
    }
}
