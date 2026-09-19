//
//  RouteRepresentable.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/09/2026.
//

import SwiftUI

public protocol RouteRepresentable {
    var routeId: String { get }
    func routeView() -> any View
}
