//
//  ProfileStorageTests.swift
//  NOIRTests
//

import Testing
@testable import NOIR

struct ProfileStorageTests {
    @Test func nameKeyIsStable() {
        #expect(ProfileStorage.nameKey == "profile.name")
    }

    @Test(arguments: [
        ("Maria", "M"),
        ("maria", "M"),
        ("  joão  ", "J"),
        ("\n\tana", "A"),
        ("élodie", "É"),
        ("👨‍👩‍👧 Family", "👨‍👩‍👧"),
        ("", ""),
        ("   ", ""),
    ])
    func initial(name: String, expected: String) {
        #expect(ProfileStorage.initial(of: name) == expected)
    }

    @Test func trimmedRemovesSurroundingWhitespaceOnly() {
        #expect(ProfileStorage.trimmed("  Ana Maria \n") == "Ana Maria")
    }

    @Test func nonBlankDraftIsStoredTrimmed() {
        #expect(ProfileStorage.nameToStore(draft: "  Maria ", current: "Henrique") == "Maria")
    }

    @Test func unchangedDraftKeepsTheName() {
        #expect(ProfileStorage.nameToStore(draft: "Henrique", current: "Henrique") == "Henrique")
    }

    @Test(arguments: ["", " ", "   \n\t "])
    func blankDraftRestoresTheStoredName(draft: String) {
        #expect(ProfileStorage.nameToStore(draft: draft, current: "Henrique") == "Henrique")
    }
}
