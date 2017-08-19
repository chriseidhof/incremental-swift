//
//  IncrementalTests.swift
//  IncrementalTests
//
//  Created by Chris Eidhof on 18.08.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import XCTest
@testable import Incremental

class IncrementalTests: XCTestCase {
    func testBasicObserving() {
        let x = Var<Int>(0)
        let i = I(variable: x)
        var result: [Int] = []
        var observer: Any? = i.observe { result.append($0) }
        XCTAssertEqual(result, [0])
        x.value = 5
        Incremental.shared.propagate()
        XCTAssertEqual(result, [0, 5])
        x.value = 10
        observer = nil
        Incremental.shared.propagate()
    }
    
    func testPropagation() {
        let x = Var(5)
        let sum = I(variable: x).zip(I(variable: x), +)
        var result: [Int] = []
        var observer: Any? = sum.observe {
            result.append($0)
        }
        Incremental.shared.propagate()
        x.value = 6
        Incremental.shared.propagate()
        XCTAssertEqual(result, [10,12]) // Note that there are only two results, unlike reactive programming.
        observer = nil
    }
    
    func testMap() {
        let x = Var(5)
        let mapped = I(variable: x).map { $0 + 1 }
        var results: [Int] = []
        var observer: Any? = mapped.observe { results.append($0) }
        Incremental.shared.propagate()
        x.value = 10
        Incremental.shared.propagate()
        
        XCTAssertEqual(results, [6,11])
        observer = nil
    }
    
    func testDeinit() {
        let x: Var<Int>? = Var(10)
        var deinited = false
        var i: I<Int>! = I(variable: x!, deinitializer: { deinited = true })
        XCTAssertFalse(deinited)
        i = nil
        XCTAssertTrue(deinited)
    }
    
    func testObserveDeinit() {
        var deinited = false
        var i: I<Int>? = I(isEqual: ==, value: 1, deinitializer: { deinited = true })
        var observer: Any? = i!.observe { _ in () }
        i = nil
        XCTAssertFalse(deinited)
        observer = nil
        XCTAssertTrue(deinited)
    }

    func testZipDeinit() {
        var x: Var<Int>! = Var(5)
        var y: Var<Int>! = Var(6)
        var deinitX = false
        var deinitY = false
        var sum: I<Int>! = I(variable: x, deinitializer: { deinitX = true }).zip(I(variable: y, deinitializer: { deinitY = true }), +)
        var result: [Int] = []
        var observer: Any? = sum!.observe { result.append($0) }
        Incremental.shared.propagate()
        
        observer = nil
        XCTAssertFalse(deinitX)
        XCTAssertFalse(deinitY)
        sum = nil
        XCTAssertTrue(deinitX)
        XCTAssertTrue(deinitY)
    }
    
}
