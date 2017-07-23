//
//  main.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

enum App {
    case counter(x: I<Int>)
    case other(I<String>)
}

extension App: Equatable {
    static func ==(lhs: App, rhs: App) -> Bool {
        return false
    }
}

let inc = Incremental()


func if_<A: Equatable>(_ cond: I<Bool>, _ then: @autoclosure @escaping () -> I<A>, else alt:  @autoclosure @escaping () -> I<A>) -> I<A> {
    return cond.flatMap { $0 ? then() : alt() }
}

func testMinimal() {
    let start: [Int] = []
    var (list, tail) = inc.list(from: start)
    let reduced = inc.reduce(isEqual: ==, list, 0, +)
    reduced.observe {
        print($0)
    }
    print("ct \(inc.currentTime)")
    for x in [0,1,2] {
        let newTail: I<IList<Int>> = inc.constant(.empty)
        tail.write(.cons(x, tail: newTail))
        tail = newTail
        inc.propagate()
    }
}

func testArray() {
    let arr = inc.array(initial: [] as [Int])
    let size: I<String> = if_(arr.latest.map { $0.count > 1 }, inc.constant("large"), else: inc.constant("small"))
    size.observe {
        print($0)
    }
    arr.change(.append(4))
    inc.propagate()
    arr.change(.append(5))
    arr.change(.insert(element: 0, at: 0))
    inc.propagate()
}

func testGui() {
    let counter = Var(0)
    let str = Var("Hi")
    let app: Var<App> = Var(App.counter(x: inc.read(counter)))
    let appI = inc.read(app)
    let strI = inc.read(str)

    let gui: I<String> = appI.flatMap { a in
        print("evaluating flatMap")
        switch a {
        case .counter(let i):
            return i.map { "counter: \($0) "}
        case .other(let s):
            return s
        }
    }

    gui.read {
        print($0)
    }

    counter.value += 1

    inc.propagate()

    print("propagated")
    app.value = .other(strI)
    counter.value = 3

    inc.propagate()
}

func test() {
    let x = Var(5)
    let y = Var(6)
    let sum = inc.read(x).zip(inc.read(y), +)
    sum.read {
        print("result: \($0)")
    }
    inc.propagate()
    print("propagated")
    
    x.value = 10
    y.value = 20
    inc.propagate()
    print("Done")
}

test()
testGui()
testArray()
testMinimal()

