//
//  RepositoryError.swift
//  NOIR
//

import Foundation

enum RepositoryError: Error {
    case notFound
    case invalidAmount
}

/// Why `createCategory` or `updateCategory` refused a name.
nonisolated enum CategoryError: Error, Equatable {
    case emptyName
    case duplicateName
}
