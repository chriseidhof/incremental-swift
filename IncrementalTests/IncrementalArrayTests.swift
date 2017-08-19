//
//  IncrementalArrayTests.swift
//  IncrementalTests
//
//  Created by Chris Eidhof on 19.08.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import XCTest
@testable import Incremental

class IncrementalArrayTests: XCTestCase {
   
    func testArray() {
        let (arr, change) = Incremental.shared.array(initial: [] as [Int])
        
        let size: I<String> = if_(arr.latest.map { $0.count > 1 }, I(constant: "large"), else: I(constant: "small"))
        var result: [String] = []
        let observer = size.observe {
            result.append($0)
        }
        XCTAssertEqual(result, ["small"])
        Incremental.shared.propagate()
        change(.append(4))
        change(.append(5))
        change(.insert(element: 0, at: 0))
        Incremental.shared.propagate()
        XCTAssertEqual(result, ["small", "large"])
        change(.append(5))
        Incremental.shared.propagate()
        XCTAssertEqual(result, ["small", "large"])
    }


    func testArrayFilter() {
        let (arr, change) = Incremental.shared.array(initial: [0, 1, 2, 3, 4, 5])
        let filtered = Incremental.shared.filter(array: arr, condition: {
            return $0 % 2 == 0
        })
        var result: [[Int]] = []
        let observer = filtered.latest.observe { i in
            result.append(i)
        }
        Incremental.shared.propagate()
        XCTAssert(result.count == 1 && result[0] == [0,2,4])
        change(.append(6))
        change(.append(7))
        Incremental.shared.propagate()
        XCTAssert(result.count == 2 && result[1] == [0,2,4,6])
    }
    
    func testArrayChanges() {
        let (arr, change) = Incremental.shared.array(initial: ["xx", "zero", "one", "two", "three", "four"])
        var latest: [String] = []
        let observer = arr.latest.observe {
            latest = $0
        }
        Incremental.shared.propagate()
        
        XCTAssertEqual(latest, ["xx", "zero", "one", "two", "three", "four"])
        change(.remove(elementAt: 0))
        Incremental.shared.propagate()
        XCTAssertEqual(latest, ["zero", "one", "two", "three", "four"])
    }
    
    func testArrayFilter2() {
        let (arr, change) = Incremental.shared.array(initial: ["xx", "zero", "one", "two", "three", "four"])
        let filtered = Incremental.shared.filter(array: arr, condition: {
            return $0.characters.count > 2
        })
        var latest: [String] = []
        let observer = filtered.latest.observe {
            latest = $0
        }
        Incremental.shared.propagate()
        
        XCTAssertEqual(latest, ["zero", "one", "two", "three", "four"])
        change(.remove(elementAt: 0))
        Incremental.shared.propagate()
        XCTAssertEqual(latest, ["zero", "one", "two", "three", "four"])

    }
    
//    func testArrayFilterSort() {
//        let (arr, change) = Incremental.shared.array(initial: ["xx", "zero", "one", "two", "three", "four"])
//        let filtered = Incremental.shared.filter(array: arr, condition: {
//            return $0.characters.count > 2
//        })
//        let x = filtered.latest.observe {
//            print($0)
//        }
//        let sorted = Incremental.shared.sort(array: filtered, String.comparator)
//        var results: [[String]] = []
//        let observer = sorted.latest.observe { i in
//            results.append(i)
//        }
//        Incremental.shared.propagate()
//        XCTAssertEqual(results[0], ["four", "one", "three", "two", "zero"])
//        change(.append("hello world"))
//        change(.append("x"))
//        change(.remove(elementAt: 0))
//        Incremental.shared.propagate()
//        XCTAssertEqual(results[1], ["four", "hello world", "one", "three", "two", "zero"])
//    }

}
