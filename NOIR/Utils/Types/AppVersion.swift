//
//  AppVersion.swift
//  NOIR
//

import Foundation

nonisolated enum AppVersion {
    /// `CFBundleShortVersionString`, or an empty string when missing.
    static func current(in bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
