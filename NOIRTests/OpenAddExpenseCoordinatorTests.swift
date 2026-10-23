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

    @Test func presentsAddExpenseWithTheHomeButtonsPresentation() {
        let home = Coordinator()
        home.presentAddExpense()
        #expect(home.sheet?.id == addExpenseID)
        #expect(home.presentationMode == .percentage(0.8))
        #expect(home.presentationDetents == [.fraction(0.8)])
    }

    /// Positive control for the next test: the sheet is a fresh presentation when nothing was up.
    @Test func alreadyOpenAddExpenseIsLeftAlone() throws {
        let home = Coordinator()
        home.presentAddExpense()
        let first = try #require(home.sheet?.coordinator)

        home.presentAddExpense()

        #expect(home.sheet?.id == addExpenseID)
        #expect(home.sheet?.coordinator === first)
    }

    @Test func replacesAnotherSheetOnHome() throws {
        let home = Coordinator()
        home.present(MainRoutes.settings(), mode: .large)
        #expect(home.sheet?.id == MainRoutes.settings().routeId)

        home.presentAddExpense()

        #expect(home.sheet?.id == addExpenseID)
        #expect(home.presentationDetents == [.fraction(0.8)])
    }

    @Test func dismissModalsClearsSheetAndFullScreen() {
        let coordinator = Coordinator()
        coordinator.present(MainRoutes.settings(), mode: .large)
        coordinator.dismissModals()
        #expect(coordinator.sheet == nil)

        coordinator.present(MainRoutes.settings(), mode: .full)
        #expect(coordinator.fullScreen != nil)
        coordinator.dismissModals()
        #expect(coordinator.fullScreen == nil)
    }

    @Test func openingClosesModalsOnOtherTabs() {
        let home = Coordinator()
        let dashboard = Coordinator()
        let search = Coordinator()
        dashboard.present(MainRoutes.settings(), mode: .large)
        search.present(MainRoutes.settings(), mode: .full)

        Coordinator.openAddExpense(home: home, otherTabs: [dashboard, search])

        #expect(home.sheet?.id == addExpenseID)
        #expect(dashboard.sheet == nil)
        #expect(search.fullScreen == nil)
    }

    @Test func openingKeepsAddExpenseAlreadyUpOnHome() throws {
        let home = Coordinator()
        home.presentAddExpense()
        let first = try #require(home.sheet?.coordinator)

        Coordinator.openAddExpense(home: home, otherTabs: [Coordinator()])

        #expect(home.sheet?.coordinator === first)
    }
}
