//
//  Decimal+Double.swift
//  NOIR
//

import Foundation

extension Decimal {
    var doubleValue: Double { NSDecimalNumber(decimal: self).doubleValue }
}
