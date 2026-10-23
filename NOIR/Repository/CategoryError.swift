//
//  CategoryError.swift
//  NOIR
//

import Foundation

/// Why `createCategory` or `updateCategory` refused a name.
nonisolated enum CategoryError: Error, Equatable {
    case emptyName
    case duplicateName
}
