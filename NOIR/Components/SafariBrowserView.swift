//
//  SafariBrowserView.swift
//  NOIR
//

import SwiftUI
import SafariServices

struct SafariBrowserView: UIViewControllerRepresentable {
    // MARK: - Properties

    let url: URL
    let onFinish: () -> Void

    // MARK: - UIViewControllerRepresentable

    func makeUIViewController(
        context: Context
    ) -> SFSafariViewController {
        let viewController = SFSafariViewController(url: url)
        viewController.delegate = context.coordinator
        return viewController
    }

    func updateUIViewController(
        _ viewController: SFSafariViewController,
        context: Context
    ) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onFinish: onFinish)
    }
}

// MARK: - Coordinator

extension SafariBrowserView {
    final class Coordinator: NSObject, SFSafariViewControllerDelegate {
        private let onFinish: () -> Void

        init(onFinish: @escaping () -> Void) {
            self.onFinish = onFinish
        }

        func safariViewControllerDidFinish(
            _ controller: SFSafariViewController
        ) {
            onFinish()
        }
    }
}

struct SafariRouteContent: View {
    let url: URL

    var body: some View {
        SafariBrowserView(url: url, onFinish: {})
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}
