//
//  Coordinator.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import Combine
import SwiftUI


public final class Coordinator: ObservableObject {
    
    @Published var path: NavigationPath = NavigationPath()
    @Published var sheet: Route?
    @Published var fullScreen: Route?
    
    private(set) weak var parent: Coordinator?
    
    var presentationMode: RoutePresentationMode?
    
    var indicatorVisibility: Visibility {
           presentationMode == .flexible ? .visible : .hidden
    }
    
    var presentationDetents: Set<PresentationDetent> {
        switch presentationMode {
        case .small:
            return [.fraction(0.3)]
        case .medium:
            return [.medium]
        case .large:
            return [.large]
        case .full:
            return [.large]
        case let .percentage(value):
            return [.fraction(value)]
        case .flexible:
            return Set(stride(from: 0.4, through: 1.0, by: 0.1).map {
                PresentationDetent.fraction($0)
            })
        case .none:
            fatalError("❌ You Shall Not Pass!")
        }
    }
    
    public init(parent: Coordinator? = nil) {
        self.parent = parent
    }
}

extension Coordinator {
    public func navigate(to route: any RouteRepresentable) {
        path.append(Route(route))
    }
    func pop() {
        guard !path.isEmpty else { return }
        path.removeLast()
    }
    
    func pop(if ready: Bool) {
        guard ready else { return }
        pop()
    }
    
    func popToRoot() {
        self.path.removeLast(self.path.count)
    }
}

extension Coordinator {
    public func dismiss() {
        if sheet != nil || fullScreen != nil {
            sheet = nil
            fullScreen = nil
        } else {
            parent?.sheet = nil
            parent?.fullScreen = nil
        }
    }
    
    public func dismiss(if ready: Bool) {
        guard ready else { return }
        dismiss()
    }

    func present(_ route: any RouteRepresentable, mode: RoutePresentationMode) {
        presentationMode = mode
        
        let modalContainer = Coordinator(parent: self)
        
        if mode == .full {
            fullScreen = Route(route, coordinator: modalContainer)
        } else {
            sheet = Route(route, coordinator: modalContainer)
        }
    }
}

extension Coordinator {
    func build(from route: any RouteRepresentable) -> any View {
        route.routeView()
    }

    func buildSheet(from route: any RouteRepresentable) -> any View {
        route.routeView()
    }
}
