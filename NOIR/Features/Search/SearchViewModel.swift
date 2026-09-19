import Foundation
import Observation
import SwiftData

@MainActor
@Observable
final class SearchViewModel {
    struct DaySection: Identifiable {
        let date: Date
        let expenses: [ExpenseDTO]

        var id: Date { date }
    }

    let repository: ExpenseRepository
    let pageSize = 50

    var query = ""
    private(set) var sections: [DaySection] = []
    private(set) var isLoading = false
    private(set) var isLoadingMore = false
    private(set) var hasMore = true
    var errorMessage: String?

    private var loadedExpenses: [ExpenseDTO] = []
    private var debounceTask: Task<Void, Never>?
    private var requestTask: Task<Void, Never>?
    private var requestID = UUID()
    private let calendar: Calendar

    init(model: ModelContainer, calendar: Calendar = .current) {
        repository = ExpenseRepository(modelContainer: model)
        self.calendar = calendar
    }

    func loadInitialPage() async {
        await reload(query: query)
    }

    func queryDidChange(_ newQuery: String) {
        query = newQuery
        debounceTask?.cancel()
        requestTask?.cancel()

        let id = UUID()
        requestID = id
        debounceTask = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(400))
                guard !Task.isCancelled else { return }
                await self?.reload(query: newQuery, requestID: id)
            } catch {
            }
        }
    }

    func loadMoreIfNeeded(after expense: ExpenseDTO) async {
        guard let lastExpense = loadedExpenses.last,
              lastExpense.id == expense.id,
              hasMore,
              !isLoading,
              !isLoadingMore else { return }

        await loadMore()
    }

    private func reload(query: String, requestID: UUID? = nil) async {
        let currentRequestID = requestID ?? UUID()
        self.requestID = currentRequestID
        requestTask?.cancel()
        loadedExpenses = []
        sections = []
        hasMore = true
        isLoading = true
        isLoadingMore = false
        errorMessage = nil

        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let expenses = try await repository.fetchPage(query: query, offset: 0, limit: pageSize)
                guard !Task.isCancelled, self.requestID == currentRequestID else { return }
                loadedExpenses = expenses
                hasMore = expenses.count == pageSize
                rebuildSections()
                isLoading = false
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == currentRequestID else { return }
                errorMessage = error.localizedDescription
                isLoading = false
            }
        }

        await requestTask?.value
    }

    private func loadMore() async {
        guard hasMore, !isLoading, !isLoadingMore else { return }
        let currentRequestID = requestID
        let offset = loadedExpenses.count
        isLoadingMore = true

        requestTask?.cancel()
        requestTask = Task { [weak self] in
            guard let self else { return }
            do {
                let expenses = try await repository.fetchPage(query: query, offset: offset, limit: pageSize)
                guard !Task.isCancelled, self.requestID == currentRequestID else { return }

                let existingIDs = Set(loadedExpenses.map(\.id))
                loadedExpenses.append(contentsOf: expenses.filter { !existingIDs.contains($0.id) })
                hasMore = expenses.count == pageSize
                rebuildSections()
                isLoadingMore = false
            } catch is CancellationError {
                return
            } catch {
                guard self.requestID == currentRequestID else { return }
                errorMessage = error.localizedDescription
                isLoadingMore = false
            }
        }

        await requestTask?.value
    }

    private func rebuildSections() {
        let grouped = Dictionary(grouping: loadedExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }

        sections = grouped.keys.sorted(by: >).map { date in
            DaySection(
                date: date,
                expenses: (grouped[date] ?? []).sorted { $0.date > $1.date }
            )
        }
    }
}
