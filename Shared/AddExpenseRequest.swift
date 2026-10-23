//
//  AddExpenseRequest.swift
//  NOIR
//

import Foundation
import Observation

@Observable
final class AddExpenseRequest {
    static let shared = AddExpenseRequest()

    private(set) var isPending = false

    func request() {
        isPending = true
    }

    func consume() -> Bool {
        defer { isPending = false }
        return isPending
    }

    func cancel() {
        isPending = false
    }
}
