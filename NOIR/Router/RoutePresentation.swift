//
//  RoutePresentation.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI

public enum RoutePresentationMode {
    case small
    case medium
    case large
    case full
    case flexible
    case percentage(CGFloat)
}

// MARK: - Equatable

extension RoutePresentationMode: Equatable {
    static public func == (
        lhs: RoutePresentationMode,
        rhs: RoutePresentationMode
    ) -> Bool {
        switch (lhs, rhs) {
        case (.small, .small):
            return true
        case (.medium, .medium):
            return true
        case (.large, .large):
            return true
        case (.flexible, .flexible):
            return true
        case (.percentage, .percentage):
            return true
        case (.full, .full):
            return true
        default:
            return false
        }
    }
}
