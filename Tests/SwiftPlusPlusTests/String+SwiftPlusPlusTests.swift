//
//  String+SwiftPlusPlusTests.swift
//  SwiftPlusPlus
//
//  Created by Andrew J Wagner on 6/8/14.
//  Copyright (c) 2014 Drewag LLC. All rights reserved.
//

import XCTest
import SwiftPlusPlus

final class String_SwiftPlusPlusTests: XCTestCase, LinuxEnforcedTestCase {
    func testRepeat() {
        XCTAssertEqual("Hello".repeating(nTimes: 3), "HelloHelloHello")
        XCTAssertEqual("Hello".repeating(nTimes: 4, separator: " "), "Hello Hello Hello Hello")
    }

    func testSubstringFromIndex() {
        let string = "Hello World"
        XCTAssertEqual(string.substring(from: 1), "ello World")
    }

    func testSubstringToIndex() {
        let string = "Hello World"
        XCTAssertEqual(string.substring(to: 1), "H")
    }

    static var allTests: [(String, (String_SwiftPlusPlusTests) -> () throws -> Void)] {
        return [
            ("testRepeat", testRepeat),
            ("testSubstringFromIndex", testSubstringFromIndex),
            ("testSubstringToIndex", testSubstringToIndex),
        ]
    }
}
