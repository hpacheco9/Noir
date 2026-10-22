//
//  StringCatalogCompletenessTests.swift
//  NOIRTests
//

import Testing
import Foundation

struct StringCatalogCompletenessTests {
    static let languages = ["de", "es", "fr", "pt-BR", "pt-PT"]
    static let catalogs = [
        "NOIR/Utils/Localizable.xcstrings",
        "NOIR/Utils/AppIntents.xcstrings",
        "NOIR/Utils/AppShortcuts.xcstrings",
        "NOIRWidget/Localizable.xcstrings",
    ]

    /// "key: language" for every key that has `en`, isn't `shouldTranslate: false` and lacks one of `languages`.
    nonisolated static func missingTranslations(in catalog: Data, languages: [String]) throws -> [String] {
        let root = try #require(try JSONSerialization.jsonObject(with: catalog) as? [String: Any])
        let strings = try #require(root["strings"] as? [String: [String: Any]])
        return strings.keys.sorted().flatMap { key -> [String] in
            let entry = strings[key]!
            let localizations = entry["localizations"] as? [String: Any] ?? [:]
            guard localizations["en"] != nil, entry["shouldTranslate"] as? Bool != false else { return [] }
            return languages.filter { localizations[$0] == nil }.map { "\(key): \($0)" }
        }
    }

    private static var repoRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }

    @Test(arguments: catalogs)
    func catalogIsComplete(path: String) throws {
        let data = try Data(contentsOf: Self.repoRoot.appending(path: path))
        let missing = try Self.missingTranslations(in: data, languages: Self.languages)
        #expect(missing.isEmpty, "\(path): \(missing)")
    }

    @Test func checkFiresOnMissingTranslation() throws {
        let sample = """
        {
          "sourceLanguage" : "en",
          "strings" : {
            "complete" : { "localizations" : { "de" : {}, "en" : {}, "es" : {}, "fr" : {}, "pt-BR" : {}, "pt-PT" : {} } },
            "half" : { "localizations" : { "de" : {}, "en" : {}, "fr" : {}, "pt-BR" : {}, "pt-PT" : {} } },
            "untranslated" : { "localizations" : { "en" : {} } },
            "verbatim" : { "localizations" : { "en" : {} }, "shouldTranslate" : false },
            "extracted_only" : {}
          }
        }
        """
        let missing = try Self.missingTranslations(in: Data(sample.utf8), languages: Self.languages)
        #expect(missing == ["half: es", "untranslated: de", "untranslated: es", "untranslated: fr", "untranslated: pt-BR", "untranslated: pt-PT"])
    }
}
