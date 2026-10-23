//
//  OpenAddExpenseCoordinatorTests.swift
//  NOIRTests
//

import Testing
import Foundation
import SwiftUI
@testable import NOIR

struct OpenAddExpenseCoordinatorTests {
    private let addExpenseID = MainRoutes.addExpense().routeId

    @Test func plusPresentsAddExpenseAtTheSharedDetent() {
        let coordinator = Coordinator()
        coordinator.presentAddExpense()
        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(coordinator.presentationDetents == [.fraction(0.8)])
    }

    @Test func controlPresentsWhenNothingIsUp() {
        let coordinator = Coordinator()
        coordinator.presentAddExpenseIfNeeded()
        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(coordinator.presentationDetents == [.fraction(0.8)])
    }

    @Test func controlLeavesAnOpenAddExpenseAlone() throws {
        let coordinator = Coordinator()
        coordinator.presentAddExpense()
        let first = try #require(coordinator.sheet?.coordinator)

        coordinator.presentAddExpenseIfNeeded()

        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(coordinator.sheet?.coordinator === first)
    }

    @Test func controlReplacesAnotherSheetOnTheSameCoordinator() {
        let coordinator = Coordinator()
        coordinator.present(MainRoutes.settings(), mode: .large)
        #expect(coordinator.sheet?.id == MainRoutes.settings().routeId)
        #expect(coordinator.presentationDetents == [.large])

        coordinator.presentAddExpenseIfNeeded()

        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(coordinator.presentationDetents == [.fraction(0.8)])
    }

    @Test func plusAndControlStillWorkAfterTheSheetIsDismissed() throws {
        let coordinator = Coordinator()
        coordinator.presentAddExpenseIfNeeded()
        let first = try #require(coordinator.sheet?.coordinator)

        coordinator.sheet = nil
        coordinator.presentAddExpense()
        let second = try #require(coordinator.sheet?.coordinator)
        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(second !== first)

        coordinator.sheet = nil
        coordinator.presentAddExpenseIfNeeded()
        let third = try #require(coordinator.sheet?.coordinator)
        #expect(coordinator.sheet?.id == addExpenseID)
        #expect(third !== second)
    }

    @Test func coordinatorsAreIndependent() {
        let home = Coordinator()
        let search = Coordinator()
        search.presentAddExpenseIfNeeded()
        #expect(search.sheet?.id == addExpenseID)
        #expect(home.sheet == nil)
    }
}
