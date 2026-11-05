//
//  ImportReviewView.swift
//  NOIR
//

import SwiftUI

struct ImportReviewView: View {
    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: ImportReviewViewModel
    let onFinish: (ImportReviewViewModel.Summary) -> Void

    init(
        parsed: ExpenseCSVReader.Parsed,
        currencyCode: String,
        onFinish: @escaping (ImportReviewViewModel.Summary) -> Void
    ) {
        _viewModel = State(initialValue: ImportReviewViewModel(parsed: parsed, currencyCode: currencyCode))
        self.onFinish = onFinish
    }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            if !viewModel.isLoading {
                summarySection
                previewSection
                dateFormatSection
                categoriesSection(createsCategories: $viewModel.createsCategories)
                duplicatesSection(skipsDuplicates: $viewModel.skipsDuplicates)
            }
        }
        .disabled(viewModel.isImporting)
        .overlay {
            if viewModel.isLoading || viewModel.isImporting {
                ProgressView()
                    .controlSize(.large)
                    .accessibilityLabel(Text(L10n.Import.progress))
            }
        }
        .interactiveDismissDisabled(viewModel.isImporting)
        .task { await viewModel.load() }
        .navigationTitle(Text(L10n.Import.csv))
        .navigationBarTitleDisplayMode(.inline)
        .alert(Text(L10n.Import.failedTitle), isPresented: .init(
            get: { viewModel.failureMessage != nil },
            set: { if !$0 { viewModel.failureMessage = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) { viewModel.failureMessage = nil }
        } message: {
            Text(viewModel.failureMessage ?? String(localized: L10n.Shared.unexpectedError))
        }
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(role: .close) {
                    coordinator.dismiss()
                }
                .disabled(viewModel.isImporting)
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(role: .confirm) {
                    Task { await runImport() }
                } label: {
                    Text(L10n.Import.confirm(viewModel.importCount))
                }
                .disabled(!viewModel.canImport)
            }
        }
    }

    private func runImport() async {
        if let summary = await viewModel.performImport() {
            Haptics.play(.success)
            onFinish(summary)
            coordinator.dismiss()
        } else if viewModel.failureMessage != nil {
            Haptics.play(.error)
        }
    }

    private var summarySection: some View {
        Section {
            Text(L10n.Import.found(viewModel.rows.count))
                .font(.headline)

            if !viewModel.invalid.isEmpty {
                DisclosureGroup {
                    ForEach(viewModel.invalid, id: \.line) { row in
                        HStack {
                            Text(L10n.Import.line(row.line))
                            Spacer()
                            Text(reason(row.reason))
                                .foregroundStyle(.secondary)
                        }
                    }
                } label: {
                    Text(L10n.Import.invalid(viewModel.invalid.count))
                }
            }
        } footer: {
            if let code = viewModel.foreignCurrency {
                Text(L10n.Import.currencyMismatch(file: code, current: viewModel.currencyCode))
            }
        }
    }

    @ViewBuilder
    private var previewSection: some View {
        let rows = viewModel.previewRows
        if !rows.isEmpty {
            Section {
                ForEach(rows) { expense in
                    ExpenseRow(expense: expense) {}
                        .allowsHitTesting(false)
                }
            } header: {
                Text(L10n.Import.preview)
            }
        }
    }

    @ViewBuilder
    private var dateFormatSection: some View {
        if viewModel.parsed.isAmbiguous {
            Section {
                Picker(selection: Binding(
                    get: { viewModel.dateFormat },
                    set: { format in Task { await viewModel.select(format) } }
                )) {
                    ForEach(viewModel.parsed.dateFormats, id: \.self) { format in
                        Text(verbatim: viewModel.sample(for: format))
                            .tag(format)
                    }
                } label: {
                    Text(L10n.Import.dateFormat)
                }
                .pickerStyle(.inline)
                .labelsHidden()
            } header: {
                Text(L10n.Import.dateFormat)
            }
        }
    }

    @ViewBuilder
    private func categoriesSection(createsCategories: Binding<Bool>) -> some View {
        let names = viewModel.newCategoryNames
        if !names.isEmpty {
            Section {
                Toggle(isOn: createsCategories) {
                    Text(L10n.Import.createCategories(names.count))
                }
                .tint(.green)
            } footer: {
                Text(verbatim: names.formatted(.list(type: .and)))
            }
        }
    }

    @ViewBuilder
    private func duplicatesSection(skipsDuplicates: Binding<Bool>) -> some View {
        if viewModel.duplicateCount > 0 {
            Section {
                Toggle(isOn: skipsDuplicates) {
                    Text(L10n.Import.skipDuplicates(viewModel.duplicateCount))
                }
                .tint(.green)
            }
        }
    }

    private func reason(_ reason: ExpenseCSVReader.InvalidReason) -> LocalizedStringResource {
        switch reason {
        case .date: L10n.Import.reasonDate
        case .amount: L10n.Import.reasonAmount
        case .columnCount: L10n.Import.reasonColumns
        }
    }
}
