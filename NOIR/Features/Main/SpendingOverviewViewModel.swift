//
//  SpendingOverviewViewModel.swift
//  NOIR
//
//  Created by Henrique Pacheco on 22/08/2026.
//

import Foundation
import SwiftUI

@Observable
@MainActor
final class SpendingOverviewViewModel {
    
    private(set) var dataPoints: [SpendingDataPoint] = []
    private(set) var totalSpent: Decimal = 0
    private(set) var comparison: PeriodComparison?
    private(set) var isComputing = false

    private(set) var appliedPeriod: SpendingPeriod?
    private var appliedSnapshotID: UUID?

    private var waiters: [UUID: (period: SpendingPeriod, continuation: CheckedContinuation<Void, Never>)] = [:]

    func apply(_ snapshot: OverviewSnapshot) {
        guard snapshot.id != appliedSnapshotID else { return }
        appliedSnapshotID = snapshot.id
        appliedPeriod = snapshot.period
        var instant = Transaction(animation: nil)
        instant.disablesAnimations = true
        withTransaction(instant) {
            dataPoints = snapshot.points
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            totalSpent = snapshot.total
            comparison = PeriodComparison.make(current: snapshot.total, previous: snapshot.previousTotal)
            isComputing = false
        }

        for (id, waiter) in waiters where waiter.period == snapshot.period {
            waiters[id] = nil
            waiter.continuation.resume()
        }
    }

    func markLoading(for period: SpendingPeriod) {
        if appliedPeriod != period { isComputing = true }
    }

    func waitUntilApplied(for period: SpendingPeriod) async {
        if appliedPeriod == period { return }
        let id = UUID()
        await withTaskCancellationHandler {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                if Task.isCancelled || appliedPeriod == period {
                    continuation.resume()
                } else {
                    waiters[id] = (period, continuation)
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in self?.cancelWaiter(id) }
        }
    }

    private func cancelWaiter(_ id: UUID) {
        waiters.removeValue(forKey: id)?.continuation.resume()
    }
}
