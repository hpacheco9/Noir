//
//  AppVersion.swift
//  NOIR
//

import Foundation

nonisolated enum AppVersion {
    static func current(in bundle: Bundle = .main) -> String {
        bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }
}
