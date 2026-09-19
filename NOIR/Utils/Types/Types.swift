//
//  Types.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/09/2026.
//

import Foundation

struct SpendingDataPoint: Identifiable {
    let id = UUID()
    let label: String
    let date: Date
    let amount: Decimal
}
