//
//  AddExpenseRequestTests.swift
//  NOIRTests
//

import Testing
import Foundation
import AppIntents
@testable import NOIR

struct AddExpenseRequestTests {
    @Test func startsIdle() {
        let request = AddExpenseRequest()
        #expect(request.isPending == false)
        #expect(request.consume() == false)
    }

    @Test func requestIsConsumedOnce() {
        let request = AddExpenseRequest()
        request.request()
        #expect(request.isPending == true)
        #expect(request.consume() == true)
        #expect(request.isPending == false)
        #expect(request.consume() == false)
    }

    @Test func repeatedRequestsCollapseIntoOne() {
        let request = AddExpenseRequest()
        request.request()
        request.request()
        #expect(request.consume() == true)
        #expect(request.consume() == false)
    }

    /// Onboarding finishing drops a request raised while it was showing.
    @Test func cancelDropsPendingRequest() {
        let request = AddExpenseRequest()
        request.request()
        request.cancel()
        #expect(request.isPending == false)
        #expect(request.consume() == false)
    }

    @Test func intentRaisesTheSharedRequest() async throws {
        let shared = AddExpenseRequest.shared
        shared.cancel()
        defer { shared.cancel() }

        _ = try await OpenAddExpenseIntent().perform()

        #expect(shared.consume() == true)
    }

    @Test func intentOpensTheApp() {
        #expect(OpenAddExpenseIntent.supportedModes.contains(.foreground))
        #expect(OpenAddExpenseIntent.supportedModes.contains(.background) == false)
    }
}
