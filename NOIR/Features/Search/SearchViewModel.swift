import Combine
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

    let repository: ExpenseRepositoryProvider
    let pageSize = 50

    var query = "" {
        didSet { querySubject.send(query) }
    }

    private(set) var sections: [DaySection] = []
    private(set) var isLoading = false
    private(set) var hasMore = true
    var errorMessage: String?

    private var loadedExpenses: [ExpenseDTO] = []
    private var loadedQuery = ""
    private var isLoadingMore = false
    private var requestID = UUID()
    private let calendar: Calendar

    @ObservationIgnored private let querySubject = PassthroughSubject<String, Never>()
    @ObservationIgnored private var subscriptions = Set<AnyCancellable>()

    init(model: ModelContainer, calendar: Calendar = .current) {
        repository = ExpenseRepositoryProvider(container: model)
        self.calendar = calendar
        querySubject
            .removeDuplicates()
            .debounce(for: .milliseconds(150), scheduler: DispatchQueue.main)
            .sink { [weak self] text in
                Task { await self?.search(text) }
            }
            .store(in: &subscriptions)
    }

    func search(_ text: String) async {
        let id = UUID()
        requestID = id
        isLoading = true
        isLoadingMore = false
        errorMessage = nil

        do {
            let expenses = try await repository.perform { [pageSize] in
                try await $0.fetchPage(query: text, offset: 0, limit: pageSize)
            }
            guard requestID == id else { return }
            loadedQuery = text
            loadedExpenses = expenses
            hasMore = expenses.count == pageSize
            rebuildSections()
        } catch {
            guard requestID == id else { return }
            loadedExpenses = []
            sections = []
            errorMessage = error.localizedDescription
        }
        isLoading = false
    }

    func loadMoreIfNeeded(after expense: ExpenseDTO) async {
        guard loadedExpenses.last?.id == expense.id, hasMore, !isLoading, !isLoadingMore else { return }

        let id = requestID
        let query = loadedQuery
        let offset = loadedExpenses.count
        isLoadingMore = true
        defer { if requestID == id { isLoadingMore = false } }

        do {
            let expenses = try await repository.perform { [pageSize] in
                try await $0.fetchPage(query: query, offset: offset, limit: pageSize)
            }
            guard requestID == id else { return }
            let existingIDs = Set(loadedExpenses.map(\.id))
            loadedExpenses.append(contentsOf: expenses.filter { !existingIDs.contains($0.id) })
            hasMore = expenses.count == pageSize
            rebuildSections()
        } catch {
            guard requestID == id else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func rebuildSections() {
        let grouped = Dictionary(grouping: loadedExpenses) { expense in
            calendar.startOfDay(for: expense.date)
        }

        sections = grouped.keys.sorted(by: >).map { date in
            // Rows arrive newest first and grouping keeps that order.
            DaySection(date: date, expenses: grouped[date] ?? [])
        }
    }
}
