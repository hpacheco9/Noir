//
//  String+SearchKey.swift
//  NOIR
//

import Foundation

extension String {
    // The one rule for "same text": ignoring case, accents and the padding around it.
    nonisolated var searchKey: String {
        trimmingCharacters(in: .whitespacesAndNewlines).folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }
}
