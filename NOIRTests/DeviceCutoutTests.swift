//
//  DeviceCutoutTests.swift
//  NOIRTests
//

import Testing
import CoreGraphics
@testable import NOIR

struct DeviceCutoutTests {
    @Test(arguments: [
        (CGFloat(0), DeviceCutout.none),
        (20, .none),
        (24, .none),
        (25, .notch),
        (44, .notch),
        (47, .notch),
        (48, .notch),
        (50, .notch),
        (51, .notch),
        (52, .dynamicIsland),
        (59, .dynamicIsland),
        (62, .dynamicIsland)
    ])
    func iPhoneCutoutFollowsTopInset(inset: CGFloat, expected: DeviceCutout) {
        #expect(DeviceCutout.make(topInset: inset, isPad: false) == expected)
    }

    @Test(arguments: [CGFloat(0), 20, 24, 50, 62])
    func iPadHasNoCutout(inset: CGFloat) {
        #expect(DeviceCutout.make(topInset: inset, isPad: true) == .none)
    }
}
