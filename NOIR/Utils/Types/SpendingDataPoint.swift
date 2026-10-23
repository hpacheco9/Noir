//
//  SpendingDataPoint.swift
//  NOIR
//

import Foundation

struct SpendingDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let amount: Decimal
}
