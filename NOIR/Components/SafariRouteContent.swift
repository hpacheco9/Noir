//
//  SafariRouteContent.swift
//  NOIR
//

import SwiftUI

struct SafariRouteContent: View {
    let url: URL

    var body: some View {
        SafariBrowserView(url: url, onFinish: {})
        .ignoresSafeArea()
        .toolbar(.hidden, for: .navigationBar)
    }
}
