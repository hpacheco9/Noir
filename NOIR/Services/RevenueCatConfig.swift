//
//  RevenueCatConfig.swift
//  NOIR
//

import Foundation
import RevenueCat

nonisolated enum RevenueCatConfig {
    // Public Apple SDK key from the RevenueCat dashboard, never a secret key.
    static let apiKey = "appl_REPLACE_ME"
    static let entitlementID = "pro"

    static let monthlyProductID = "henrique-dev.NOIR.pro.monthly"
    static let yearlyProductID = "henrique-dev.NOIR.pro.yearly"
    static let lifetimeProductID = "henrique-dev.NOIR.pro.lifetime"

    static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    static func configure() {
#if DEBUG
        Purchases.logLevel = .debug
#endif
        Purchases.configure(withAPIKey: apiKey)
    }
}
