//
//  CategoryFormView.swift
//  NOIR
//

import SwiftUI

struct CategoryFormView: View {
    /// `nil` creates a category; a custom category edits it.
    let category: CategoryInfo?

    @EnvironmentObject private var coordinator: Coordinator
    @State private var viewModel: CategoryFormViewModel
    /// Late results (save/delete) must not close some other sheet if this one is already gone.
    @State private var isOnScreen = false
    @FocusState private var isNameFocused: Bool
    @State private var isDeleteConfirmationPresented = false
    @State private var isRestoreConfirmationPresented = false

    init(category: CategoryInfo?) {
        self.category = category
        _viewModel = State(initialValue: CategoryFormViewModel(editing: category))
    }

    @ScaledMetric(relativeTo: .title3) private var tileSize: CGFloat = 52
    @ScaledMetric(relativeTo: .body) private var swatchSize: CGFloat = 44
    @ScaledMetric(relativeTo: .title) private var previewSize: CGFloat = 112
    @ScaledMetric(relativeTo: .title) private var previewGlyphSize: CGFloat = 44

    private var symbolColumns: [GridItem] { [GridItem(.adaptive(minimum: tileSize), spacing: 12)] }
    private var colorColumns: [GridItem] { [GridItem(.adaptive(minimum: swatchSize), spacing: 12)] }

    var body: some View {
        @Bindable var viewModel = viewModel

        Form {
            Section {
                preview
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }

            Section {
                TextField(String(localized: L10n.NewCategory.namePlaceholder), text: $viewModel.name)
                    .textInputAutocapitalization(.sentences)
                    .focused($isNameFocused)
                    .submitLabel(.done)
                    .onSubmit { isNameFocused = false }
                    .onChange(of: viewModel.name) { viewModel.nameDidChange() }
            } header: {
                Text(L10n.NewCategory.nameSection)
            } footer: {
                if let message = viewModel.visibleMessage {
                    Text(message)
                        .foregroundStyle(.red)
                }
            }

            Section(String(localized: L10n.NewCategory.symbolSection)) {
                LazyVGrid(columns: symbolColumns, spacing: 12) {
                    ForEach(AssetName.CategorySymbols.all, id: \.self) { symbol in
                        symbolButton(symbol)
                    }
                }
                .padding(.vertical, 8)
            }

            Section(String(localized: L10n.NewCategory.colorSection)) {
                LazyVGrid(columns: colorColumns, spacing: 12) {
                    ForEach(CategoryColor.allCases) { option in
                        colorButton(option)
                    }
                }
                .padding(.vertical, 8)
            }

            if viewModel.canRestore {
                Section {
                    Button(role: .destructive) {
                        isRestoreConfirmationPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: AssetName.System.reset)
                            Text(L10n.NewCategory.restoreDefault)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isWorking)
                }
            }

            if viewModel.canDelete {
                Section {
                    Button(role: .destructive) {
                        isDeleteConfirmationPresented = true
                    } label: {
                        HStack {
                            Spacer()
                            Image(systemName: AssetName.System.delete)
                            Text(L10n.Shared.delete)
                            Spacer()
                        }
                    }
                    .disabled(viewModel.isWorking)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .task { await viewModel.loadExistingNames() }
        .onAppear { isOnScreen = true }
        .onDisappear { isOnScreen = false }
        .alert(Text(L10n.Categories.errorTitle), isPresented: .init(
            get: { viewModel.deleteErrorMessage != nil },
            set: { if !$0 { viewModel.deleteErrorMessage = nil } }
        )) {
            Button(String(localized: L10n.Shared.ok), role: .cancel) {}
        } message: {
            Text(viewModel.deleteErrorMessage ?? "")
        }
        .alert(Text(L10n.NewCategory.restoreTitle), isPresented: $isRestoreConfirmationPresented) {
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.NewCategory.restoreDefault), role: .destructive) {
                Task {
                    if await viewModel.restoreDefault(), isOnScreen { coordinator.dismiss() }
                }
            }
        } message: {
            Text(L10n.NewCategory.restoreMessage)
        }
        .alert(Text(L10n.Categories.deleteTitle), isPresented: $isDeleteConfirmationPresented) {
            Button(String(localized: L10n.Shared.cancel), role: .cancel) {}
            Button(String(localized: L10n.Shared.delete), role: .destructive) {
                Task {
                    if await viewModel.delete(), isOnScreen { coordinator.dismiss() }
                }
            }
        } message: {
            Text(L10n.Categories.deleteMessage)
        }
        .navigationTitle(Text(viewModel.title))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: L10n.Shared.cancel)) {
                    coordinator.dismiss()
                }
            }

            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: L10n.Shared.save)) {
                    Task {
                        switch await viewModel.save() {
                        case .saved:
                            if isOnScreen {
                                Haptics.play(.success)
                                coordinator.dismiss()
                            }
                        case .failed:
                            if isOnScreen { Haptics.play(.error) }
                        case .skipped:
                            break
                        }
                    }
                }
                .disabled(!viewModel.canSave)
            }
        }
    }

    // MARK: - Pieces

    private var preview: some View {
        VStack(spacing: 12) {
            Image(systemName: viewModel.symbol)
                .font(.system(size: previewGlyphSize, weight: .semibold))
                .foregroundStyle(viewModel.displayColor)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: previewSize, height: previewSize)
                .background(viewModel.displayColor.opacity(0.15), in: Circle())

            Text(viewModel.trimmedName.isEmpty ? String(localized: L10n.NewCategory.previewPlaceholder) : viewModel.trimmedName)
                .font(.title3.weight(.semibold))
                .foregroundStyle(viewModel.trimmedName.isEmpty ? .secondary : .primary)
                .lineLimit(1)
                .contentTransition(.interpolate)
        }
        .frame(maxWidth: .infinity)
        .animation(.snappy, value: viewModel.symbol)
        .animation(.snappy, value: viewModel.color)
        .accessibilityElement(children: .combine)
    }

    private func symbolButton(_ symbol: String) -> some View {
        let isSelected = viewModel.symbol == symbol
        return Button {
            viewModel.symbol = symbol
        } label: {
            Image(systemName: symbol)
                .font(.title3)
                .foregroundStyle(.primary)
                .frame(width: tileSize, height: tileSize)
                .background(isSelected ? Color(.systemFill) : Color(.tertiarySystemFill), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 3)
                        .opacity(isSelected ? 1 : 0)
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(Self.readableName(of: symbol)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    /// "cup.and.saucer.fill" -> "cup and saucer"
    private static func readableName(of symbol: String) -> String {
        symbol.split(separator: ".").filter { $0 != "fill" }.joined(separator: " ")
    }

    private func colorButton(_ option: CategoryColor) -> some View {
        let isSelected = viewModel.color == option
        return Button {
            viewModel.color = option
        } label: {
            Circle()
                .fill(option.color)
                .frame(width: swatchSize - 12, height: swatchSize - 12)
                .padding(4)
                .overlay {
                    Circle()
                        .strokeBorder(Color.primary, lineWidth: 2)
                        .opacity(isSelected ? 1 : 0)
                }
                .frame(width: swatchSize, height: swatchSize)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(option.title))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

#Preview {
    CoordinatorView {
        CategoryFormView(category: nil)
    }
    .environmentObject(Coordinator())
}
