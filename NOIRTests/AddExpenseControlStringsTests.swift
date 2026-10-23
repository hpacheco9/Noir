//
//  AddExpenseControlStringsTests.swift
//  NOIRTests
//

import Testing
import Foundation

/// `OpenAddExpenseIntent` is compiled into the app and the widget extension, so its title key must exist in both bundles' catalogs.
struct AddExpenseControlStringsTests {
    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    nonisolated static func keys(in path: String) throws -> Set<String> {
        let data = try Data(contentsOf: repoRoot.appending(path: path))
        let root = try #require(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        return Set(try #require(root["strings"] as? [String: Any]).keys)
    }

    @Test(arguments: ["NOIR/Utils/Localizable.xcstrings", "NOIRWidget/Localizable.xcstrings"])
    func intentTitleIsInCatalog(path: String) throws {
        #expect(try Self.keys(in: path).contains("app_intent.open_add_expense"))
    }

    @Test func controlStringsAreInTheWidgetCatalog() throws {
        let keys = try Self.keys(in: "NOIRWidget/Localizable.xcstrings")
        #expect(keys.contains("widget.add_expense.display_name"))
        #expect(keys.contains("widget.add_expense.description"))
    }

    /// Positive control: the lookup does report a key that is absent.
    @Test func missingKeyIsReported() throws {
        #expect(try Self.keys(in: "NOIRWidget/Localizable.xcstrings").contains("no.such.key") == false)
    }
}
