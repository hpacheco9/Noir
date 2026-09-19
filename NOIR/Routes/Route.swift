//
//  Route.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/09/2026.
//

import Foundation

struct Route {
    // MARK: - Properties

    let base: any RouteRepresentable
    let coordinator: Coordinator?

    // MARK: - Init

    init(_ base: any RouteRepresentable, coordinator: Coordinator? = nil) {
        self.base = base
        self.coordinator = coordinator
    }
}

// MARK: - Identifiable

extension Route: Identifiable {
    var id: String { base.routeId }
}

// MARK: - Hashable

extension Route: Hashable {
    func hash(into hasher: inout Hasher) {
        hasher.combine(base.routeId)
    }
}

// MARK: - Equatable

extension Route: Equatable {
    static func == (lhs: Route, rhs: Route) -> Bool {
        lhs.base.routeId == rhs.base.routeId
    }
}
