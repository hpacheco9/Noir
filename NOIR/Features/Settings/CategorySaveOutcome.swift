//
//  CategorySaveOutcome.swift
//  NOIR
//

import Foundation

/// What `CategoryFormViewModel.save()` did, so the view reacts (haptic, dismiss) only to a real result.
enum CategorySaveOutcome: Equatable {
    case saved
    /// Nothing was attempted (nothing to save, or a save is already in flight).
    case skipped
    case failed
}
