//
//  NotificationCenterClient.swift
//  NOIR
//

import Foundation
import UserNotifications

protocol NotificationCenterClient: Sendable {
    func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool
    /// Current permission state. Reading it never shows the system prompt.
    func authorizationStatus() async -> UNAuthorizationStatus
    func add(_ request: UNNotificationRequest) async throws
}

// `nonisolated`: under default MainActor isolation the completion handlers below would be inferred
// MainActor, but UserNotifications calls them on a background queue.
extension UNUserNotificationCenter: NotificationCenterClient {
    nonisolated func requestAuthorization(options: UNAuthorizationOptions) async throws -> Bool {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Bool, Error>) in
            requestAuthorization(options: options) { granted, error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume(returning: granted) }
            }
        }
    }

    nonisolated func authorizationStatus() async -> UNAuthorizationStatus {
        await notificationSettings().authorizationStatus
    }

    nonisolated func add(_ request: UNNotificationRequest) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            add(request) { error in
                if let error { continuation.resume(throwing: error) }
                else { continuation.resume() }
            }
        }
    }
}
