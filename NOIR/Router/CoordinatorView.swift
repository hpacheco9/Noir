//
//  CoordinatorView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 24/07/2026.
//

import SwiftUI

struct CoordinatorView<RootView: View>: View {
    @EnvironmentObject var router: Coordinator
    @ViewBuilder let rootView: () -> RootView
    
    var body: some View {
        NavigationStack(path: $router.path) {
            rootView()
                .navigationDestination(for: Route.self) { page in
                    AnyView(router.build(from: page.base))
                }
                .sheet(item: $router.sheet){ sheet in
                    ModalCoordinatorView(initialRoute: sheet)
                        .presentationDragIndicator(router.indicatorVisibility)
                        .presentationDetents(router.presentationDetents)
                }
                .fullScreenCover(item: $router.fullScreen){ fullscreen in
                    ModalCoordinatorView(initialRoute: fullscreen)
                        .presentationDragIndicator(router.indicatorVisibility)
                        .presentationDetents(router.presentationDetents)
            }
        }
    }
}

#Preview {
    CoordinatorView {
        Text("Hello World")
    }
    .environmentObject(Coordinator())
}
