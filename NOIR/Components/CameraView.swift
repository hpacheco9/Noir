//
//  CameraView.swift
//  NOIR
//
//  Created by Henrique Pacheco on 18/08/2026.
//

import SwiftUI

struct CameraView: View {
    @StateObject private var camera = CameraModel()
    @EnvironmentObject var coordiantor: Coordinator
    
    var body: some View {
        ZStack {
            if camera.isAuthorized {
                CameraPreview(session: camera.session)
                    .ignoresSafeArea()

                VStack {
                    Spacer()

                    ZStack {
                        Button {
                            camera.capturePhoto()
                        } label: {
                            Circle()
                                .fill(.white)
                                .frame(width: 70, height: 70)
                                .overlay {
                                    Circle()
                                        .stroke(
                                            .white.opacity(0.5),
                                            lineWidth: 4
                                        )
                                        .frame(width: 84, height: 84)
                                }
                        }

                        // Dismiss button
                        HStack {
                            Button {
                                coordiantor.dismiss()
                            } label: {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 20, weight: .semibold))
                                    .frame(width: 30, height: 30)
                            }
                            .buttonStyle(.glass)
                            .buttonBorderShape(.circle)

                            Spacer()
                        }
                        .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 40)
                }
            } else {
                UnavailableView(
                    "Camera Access Needed",
                    systemImage: "camera.fill",
                    description: "Allow camera access in Settings to take a photo."
                )
            }
        }
        .onChange(of: camera.capturedImage) { _, newImage in
            guard newImage != nil else { return }

            coordiantor.dismiss()
        }
        .task {
            await camera.checkPermissions()
        }
    }
}

#Preview {
    CameraView()
}
