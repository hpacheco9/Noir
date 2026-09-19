//
//  AddExpenseView.swift
//  NOIR
//

import Foundation
import SwiftUI

struct AddExpenseView: View {
    let expense: ExpenseDTO?

    @EnvironmentObject private var coordinator: Coordinator
    @Environment(ExpenseViewModel.self) private var expenseViewModel

    @FocusState private var isAmountFocused: Bool
    @State private var saveError: String?
    @State private var isDeleteConfirmationPresented = false
    @State private var isLocationPickerPresented = false
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode

    private var currencyFormat: Decimal.FormatStyle.Currency {
        .init(code: currencyCode, locale: .current)
    }

    private var title: LocalizedStringResource {
        expense == nil ? L10n.AddExpenseView.createTitle : L10n.AddExpenseView.editTitle
    }

    var body: some View {
        @Bindable var expenseViewModel = expenseViewModel

        List {
            TextField(
                String(localized: L10n.AddExpenseView.amountPlaceholder),
                value: $expenseViewModel.amount,
                format: currencyFormat
            )
            .focused($isAmountFocused)
            .keyboardType(.decimalPad)
            .multilineTextAlignment(.center)
            .font(.system(size: 48, weight: .semibold, design: .rounded))
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity)
            .accessibilityLabel(Text(L10n.AddExpenseView.amountAccessibilityLabel))
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
            .listRowSeparator(.hidden)
            
            Section(String(localized: L10n.AddExpenseView.expenseSection)) {
                TextField(String(localized: L10n.AddExpenseView.name), text: $expenseViewModel.name)
                    .textInputAutocapitalization(.sentences)
            }
            
            Section(String(localized: L10n.AddExpenseView.detailsSection)) {
                DatePicker(String(localized: L10n.AddExpenseView.date), selection: $expenseViewModel.date, displayedComponents: .date)

                Toggle("Recurring expense", isOn: $expenseViewModel.isRecurring)
                
                Picker(String(localized: L10n.AddExpenseView.category), selection: $expenseViewModel.category) {
                    ForEach(ExpenseCategory.allCases) { category in
                        Label {
                            Text(category.title)
                        } icon: {
                            Image(systemName: category.icon)
                                .foregroundStyle(category.color)
                        }
                        .tag(category)
                    }
                }
                .pickerStyle(.menu)
            }
            
            Section(String(localized: L10n.AddExpenseView.descriptionSection)) {
                TextField(String(localized: L10n.AddExpenseView.notePlaceholder), text: $expenseViewModel.description, axis: .vertical)
                    .lineLimit(3...6)
            }

            Section("Location") {
                Button {
                    isLocationPickerPresented = true
                } label: {
                    VStack(alignment: .leading, spacing: 10) {
                        if let location = expenseViewModel.location {
                            LocationMapPreview(location: location)
                        } else {
                            ContentUnavailableView {
                                Label("Current location", systemImage: "location.fill")
                            } description: {
                                Text("Tap to add your current location")
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 110)
                        }

                        HStack(spacing: 8) {
                            Image(systemName: "location.fill")
                                .foregroundStyle(.blue)
                            Text(expenseViewModel.location?.name ?? "Use current location")
                                .foregroundStyle(.primary)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $isLocationPickerPresented) {
                    NavigationStack {
                        LocationPickerView(location: $expenseViewModel.location)
                            .padding()
                            .navigationTitle("Location")
                            .navigationBarTitleDisplayMode(.inline)
                            .toolbar {
                                ToolbarItem(placement: .confirmationAction) {
                                    Button("Done") { isLocationPickerPresented = false }
                                }
                            }
                    }
                    .presentationDetents([.medium, .large])
                }
            }
            
            if expenseViewModel.isEditing {
                Button(role: .destructive) {
                    isDeleteConfirmationPresented = true
                } label: {
                    HStack {
                        Spacer()
                        Image(systemName: "trash")
                        Text("Delete")
                        Spacer()
                    }
                }
            }
        }
        .task(id: expense?.id) {
            expenseViewModel.configure(with: expense)
        }
        .onDisappear {
            expenseViewModel.reset()
        }
        .navigationTitle(expenseViewModel.title)
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(L10n.AddExpenseView.saveErrorTitle), isPresented: .init(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { saveError = nil }
        } message: {
            Text(saveError ?? String(localized: L10n.Shared.unexpectedError))
        }
        .alert(Text(L10n.ExpenseDeletion.title), isPresented: $isDeleteConfirmationPresented) {
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Shared.delete), role: .destructive) {
                Task {
                    do {
                        try await expenseViewModel.delete()
                        coordinator.dismiss()
                    } catch {
                        saveError = error.localizedDescription
                    }
                }
            }
        } message: {
            Text(L10n.ExpenseDeletion.message)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(String(localized: L10n.Shared.cancel), systemImage: AssetName.System.close) {
                    coordinator.dismiss()
                }
                .accessibilityLabel(Text(L10n.AddExpenseView.closeAccessibilityLabel))
            }

            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: L10n.Shared.save), systemImage: AssetName.System.checkmark) {
                    Task {
                        do {
                            try await expenseViewModel.save()
                            coordinator.dismiss()
                        } catch {
                            saveError = error.localizedDescription
                        }
                    }
                }
                .disabled(!expenseViewModel.canSave)
                .buttonStyle(.borderedProminent)
                .tint(.primary)
                .accessibilityLabel(Text(L10n.AddExpenseView.saveAccessibilityLabel))
            }
        }
    }
}

#Preview {
    CoordinatorView {
        AddExpenseView(expense: nil)
            .environment(ExpenseViewModel(model: NOIRApp.sharedModelContainer))
    }
    .environmentObject(Coordinator())
}
