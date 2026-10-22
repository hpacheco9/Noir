//
//  DashboardView.swift
//  NOIR
//

import SwiftUI
import SwiftData

struct DashboardView: View {
    @State private var viewModel: DashboardViewModel
    @AppStorage(CurrencyPreference.storageKey) private var currencyCode = CurrencyPreference.defaultCode
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The category whose row the user tapped; stays until tapped again or the new period's data lands.
    @State private var pinnedCategoryKey: String?
    /// The sector being scrubbed on the chart.
    @State private var angleSelection: Double?

    init(viewModel: DashboardViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    var body: some View {
        List {
            switch viewModel.state {
            case .loading:
                Section {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            case .empty:
                emptySection
            case .failed:
                failedSection
            case .loaded(let breakdown):
                loadedSections(breakdown)
            }
        }
        .listStyle(.insetGrouped)
        .animation(reduceMotion ? nil : .smooth, value: viewModel.loadedPeriod)
        .onAppear { viewModel.didAppear() }
        .onDisappear { viewModel.didDisappear() }
        .onReceive(NotificationCenter.default.publisher(for: .expensesDidChange)) { _ in
            viewModel.markDirty()
        }
        .onReceive(NotificationCenter.default.publisher(for: .categoriesDidChange)) { _ in
            viewModel.markDirty()
        }
        .onChange(of: viewModel.loadedPeriod) { old, new in
            pinnedCategoryKey = nil
            angleSelection = nil
            guard old != nil, let new else { return }
            announce(new)
        }
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                ProfileAvatarButton()
            }

            ToolbarItem(placement: .confirmationAction) {
                PeriodMenu(selection: Binding(get: { viewModel.period }, set: { viewModel.selectPeriod($0) }))
            }
        }
        //.navigationTitle(Text(L10n.Dashboard.title))
    }

    // MARK: - Sections

    private var emptySection: some View {
        Section {
            UnavailableView(
                L10n.Dashboard.emptyTitle,
                systemImage: AssetName.System.dashboard,
                description: L10n.Dashboard.emptyDescription
            )
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 50)
        }
    }

    private var failedSection: some View {
        Section {
            VStack(spacing: 12) {
                UnavailableView(
                    L10n.Dashboard.errorTitle,
                    systemImage: AssetName.System.warning,
                    description: L10n.Dashboard.errorDescription
                )

                Button(String(localized: L10n.Dashboard.retry)) {
                    viewModel.retry()
                }
                .buttonStyle(.bordered)
            }
            .frame(maxWidth: .infinity)
            .listRowSeparator(.hidden)
            .listRowBackground(Color.clear)
            .padding(.top, 50)
        }
    }

    @ViewBuilder
    private func loadedSections(_ breakdown: CategoryBreakdown) -> some View {
        let slices = DonutSlice.make(from: breakdown.categories, restTitle: String(localized: L10n.Dashboard.rest))
        let scrubKey = angleSelection.flatMap { DonutSlice.key(atAngle: $0, in: slices) }
        let pinned = breakdown.categories.first { $0.info.key == pinnedCategoryKey }
        let pinnedSliceKey = pinned.flatMap { DonutSlice.key(forCategory: $0.info.key, in: slices) }
        let selectedKey = scrubKey ?? pinnedSliceKey

        let shownPeriod = viewModel.loadedPeriod ?? viewModel.period

        Section {
            VStack(alignment: .leading, spacing: 16) {
                cardHeader()

                CategoryDonutChart(
                    slices: slices,
                    total: breakdown.total,
                    periodTitle: shownPeriod.title,
                    currencyCode: currencyCode,
                    selectedKey: selectedKey,
                    focus: focus(scrubKey: scrubKey, pinned: pinned, pinnedSliceKey: pinnedSliceKey, slices: slices),
                    angleSelection: $angleSelection
                )
                .frame(height: 280)
                // Only the finger moving onto a sector: not a release back to a pinned row, not a reload.
                .hapticFeedback(.selection, trigger: scrubKey) { _, new in new != nil }
            }
            .padding(.vertical, 8)
        }

        Section(String(localized: L10n.Dashboard.byCategory)) {
            ForEach(breakdown.categories) { spending in
                let key = spending.info.key
                CategoryRow(
                    spending: spending,
                    total: breakdown.total,
                    currencyCode: currencyCode,
                    isHighlighted: isHighlighted(key, scrubKey: scrubKey, slices: slices)
                ) {
                    toggle(key)
                }
            }
        }
    }

    // MARK: - Card header

    /// Grey label in the style of Home's overview card; the period total itself sits in the donut's centre.
    private func cardHeader() -> some View {
        Text(L10n.Dashboard.chartLabel)
            .font(.title3)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityHidden(true)
    }

    // MARK: - Selection

    /// While scrubbing, the whole sector's rows light up; otherwise only the pinned row.
    private func isHighlighted(_ categoryKey: String, scrubKey: String?, slices: [DonutSlice]) -> Bool {
        if let scrubKey {
            return slices.first { $0.key == scrubKey }?.memberKeys.contains(categoryKey) ?? false
        }
        return pinnedCategoryKey == categoryKey
    }

    private func focus(
        scrubKey: String?, pinned: CategorySpending?, pinnedSliceKey: String?, slices: [DonutSlice]
    ) -> DonutFocus? {
        if let scrubKey, let slice = slices.first(where: { $0.key == scrubKey }) {
            return DonutFocus(title: slice.title, amount: slice.amount, subtitle: nil)
        }
        guard let pinned else { return nil }
        let subtitle = pinnedSliceKey == DonutSlice.restKey
            ? String(localized: L10n.Dashboard.inRest(String(localized: L10n.Dashboard.rest)))
            : nil
        return DonutFocus(title: pinned.info.title, amount: pinned.amount, subtitle: subtitle)
    }

    private func toggle(_ categoryKey: String) {
        Haptics.play(.tap)
        angleSelection = nil
        pinnedCategoryKey = (pinnedCategoryKey == categoryKey) ? nil : categoryKey
    }

    private func announce(_ period: SpendingPeriod) {
        let total: Decimal
        if case .loaded(let breakdown) = viewModel.state { total = breakdown.total } else { total = 0 }
        var text = AttributedString(String(localized: L10n.Dashboard.announcement(
            period: period.title,
            total: CurrencyPreference.string(for: total, code: currencyCode)
        )))
        // High priority, so the menu's own speech doesn't cut it off.
        text.accessibilitySpeechAnnouncementPriority = .high
        AccessibilityNotification.Announcement(text).post()
    }
}

// MARK: - Row

private struct CategoryRow: View {
    let spending: CategorySpending
    let total: Decimal
    let currencyCode: String
    let isHighlighted: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: spending.info.icon)
                    .font(.headline)
                    .foregroundStyle(spending.info.color)
                    .frame(width: 40, height: 40)
                    .background(spending.info.color.opacity(0.12), in: Circle())

                VStack(alignment: .leading) {
                    Text(verbatim: spending.info.title)
                        .font(.headline)
                        .lineLimit(1)

                    Text(L10n.Dashboard.expenseCount(spending.count))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Spoken once, through the explicit value below.
                VStack(alignment: .trailing) {
                    Text(verbatim: CurrencyPreference.string(for: spending.amount, code: currencyCode))
                        .font(.headline)

                    Text(verbatim: CategoryDonutChart.percentString(spending.amount, of: total))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .accessibilityHidden(true)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(isHighlighted ? spending.info.color.opacity(0.12) : nil)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text(L10n.Dashboard.value(
            amount: CurrencyPreference.string(for: spending.amount, code: currencyCode),
            percent: CategoryDonutChart.percentString(spending.amount, of: total)
        )))
        .accessibilityHint(Text(L10n.Dashboard.rowHint))
        .accessibilityAddTraits(isHighlighted ? .isSelected : [])
    }
}

// MARK: - Preview

#Preview("Loaded") {
    let container = try! ModelContainer(
        for: Expense.self, CustomCategory.self, BuiltInCategoryOverride.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let context = ModelContext(container)
    let samples: [(Double, ExpenseCategory)] = [
        (42.5, .food), (18, .food), (60, .transport), (120, .home), (35, .leisure),
        (22, .health), (80, .shopping), (9.9, .other),
    ]
    for (index, sample) in samples.enumerated() {
        context.insert(Expense(amount: sample.0, name: "Sample \(index)", date: .now, category: sample.1))
    }
    try? context.save()

    return CoordinatorView {
        DashboardView(viewModel: DashboardViewModel(model: container))
    }
    .environmentObject(Coordinator())
}
