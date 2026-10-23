//
//  AddExpenseRequest.swift
//  NOIR
//

import Foundation
import Observation

/// "Open Add Expense" asked from outside the UI (the Control Center / Lock Screen / Action button control).
/// The intent runs in the app process and only raises the flag, `RootView` consumes it.
@Observable
final class AddExpenseRequest {
    static let shared = AddExpenseRequest()

    private(set) var isPending = false

    init() {}

    func request() {
        isPending = true
    }

    /// True once per request.
    func consume() -> Bool {
        defer { isPending = false }
        return isPending
    }

    func cancel() {
        isPending = false
    }
}
