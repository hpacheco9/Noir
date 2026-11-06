//
//  ProAccessTests.swift
//  NOIRTests
//

import Testing
import Foundation
@testable import NOIR

struct ProAccessTests {
    private func withIsolatedDefaults<T>(_ body: (UserDefaults) throws -> T) rethrows -> T {
        let suite = "NOIRTests.proAccess.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        return try body(defaults)
    }

    @Test func nothingIsCachedBeforeTheFirstWrite() {
        withIsolatedDefaults { defaults in
            #expect(ProAccess.cached(in: defaults) == nil)
            ProAccess.cache(true, in: defaults)
            #expect(ProAccess.cached(in: defaults) == true)
        }
    }

    @Test func accessIsGrantedOnlyByACachedTrue() {
        withIsolatedDefaults { defaults in
            #expect(!ProAccess.isGranted(in: defaults))
            ProAccess.cache(false, in: defaults)
            #expect(!ProAccess.isGranted(in: defaults))
            ProAccess.cache(true, in: defaults)
            #expect(ProAccess.isGranted(in: defaults))
        }
        #expect(!ProAccess.isGranted(in: nil))
    }

    @Test func cachingReportsWhetherTheValueChanged() {
        withIsolatedDefaults { defaults in
            #expect(ProAccess.cache(false, in: defaults))
            #expect(!ProAccess.cache(false, in: defaults))
            #expect(ProAccess.cache(true, in: defaults))
            #expect(!ProAccess.cache(true, in: defaults))
            #expect(ProAccess.cache(false, in: defaults))
        }
    }}
