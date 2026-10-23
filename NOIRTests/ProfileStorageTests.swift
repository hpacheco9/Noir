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

    @Test(arguments: ["", " ", "   \n\t "])
    func leavingWithABlankDraftRestoresTheNameFromEntry(draft: String) {
        #expect(ProfileStorage.nameOnLeaving(draft: draft, entry: "Maria") == "Maria")
    }

    @Test func leavingWithANameKeepsItTrimmed() {
        #expect(ProfileStorage.nameOnLeaving(draft: " Marta ", entry: "Maria") == "Marta")
    }

    @Test func backspacingTheWholeNameRestoresTheOriginal() {
        let entry = "Maria"
        var stored = entry
        for draft in ["Mari", "Mar", "Ma", "M", ""] {
            stored = ProfileStorage.nameToStore(draft: draft, current: stored)
        }
        #expect(stored == "M")
        #expect(ProfileStorage.nameOnLeaving(draft: "", entry: entry) == "Maria")
    }
}
