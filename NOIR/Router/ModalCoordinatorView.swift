//
//  ModalCoordinatorView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 17/09/2026.
//

import SwiftUI

struct ModalCoordinatorView: View {
    // MARK: - Properties

    @ObservedObject var modalCoordinator: Coordinator

    let initialRoute: Route

    // MARK: - Init

    init(initialRoute: Route) {
        self.initialRoute = initialRoute
        if let provided = initialRoute.coordinator {
            modalCoordinator = provided
        } else {
            modalCoordinator = Coordinator()
        }
    }

    // MARK: - View

    var body: some View {
        NavigationStack(path: $modalCoordinator.path) {
            AnyView(modalCoordinator.buildSheet(from: initialRoute.base)
                .navigationDestination(for: Route.self) { page in
                    AnyView(modalCoordinator.build(from: page.base))
                })
                .sheet(item: $modalCoordinator.sheet) { sheet in
                    ModalCoordinatorView(initialRoute: sheet)
                        .presentationDetents(
                            modalCoordinator.presentationDetents
                        )
                        .presentationDragIndicator(
                            modalCoordinator.indicatorVisibility
                        )
                }
                .fullScreenCover(
                    item: $modalCoordinator.fullScreen
                ) { view in
                    ModalCoordinatorView(initialRoute: view)
                        .presentationDetents(
                            modalCoordinator.presentationDetents
                        )
                        .presentationDragIndicator(
                            modalCoordinator.indicatorVisibility
                        )
                }
        }
        .environmentObject(modalCoordinator)
    }
}
