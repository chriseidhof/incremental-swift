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

func if_<A: Equatable>(_ cond: I<Bool>, _ then: @autoclosure @escaping () -> I<A>, else alt:  @autoclosure @escaping () -> I<A>) -> I<A> {
    return cond.flatMap { $0 ? then() : alt() }
}

func testMinimal() {
    let start: [Int] = []
    var (list, tail) = Incremental.shared.list(from: start)
    let reduced = Incremental.shared.reduce(isEqual: ==, list, 0, +)
    reduced.observe {
        print($0)
    }
    for x in [0,1,2] {
        let newTail: I<IList<Int>> = I(.empty)
        tail.write(.cons(x, tail: newTail))
        tail = newTail
        Incremental.shared.propagate()
    }
}

func testArray() {
    let (arr, change) = Incremental.shared.array(initial: [] as [Int])
    let latest: I<[Int]> = Incremental.shared.reduce(isEqual: ==, arr.changes, arr.initial) { l, el in
        l.applying(change: el)
    }

    let size: I<String> = if_(latest.map { $0.count > 1 }, I("large"), else: I("small"))
    size.observe {
        print($0)
    }
    change(.append(4))
    Incremental.shared.propagate()
    change(.append(5))
    change(.insert(element: 0, at: 0))
    Incremental.shared.propagate()
}

func testGui() {
    let counter = Var(0)
    let str = Var("Hi")
    let app: Var<App> = Var(App.counter(x: I(variable: counter)))
    let appI = I(variable: app)
    let strI = I(variable: str)

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

    Incremental.shared.propagate()

    print("propagated")
    app.value = .other(strI)
    counter.value = 3

    Incremental.shared.propagate()
}

func test() {
    let x = Var(5)
    let y = Var(6)
    let sum = I(variable: x).zip(I(variable: y), +)
    sum.read {
        print("result: \($0)")
    }
    Incremental.shared.propagate()
    print("propagated")
    
    x.value = 10
    y.value = 20
    Incremental.shared.propagate()
    print("Done")
}

func test2() {
    let x = Var(5)
    let sum = I(variable: x).zip(I(variable: x), +)
    sum.read {
        print("sum: \($0)")
    }
    Incremental.shared.propagate()
    x.value = 6
    Incremental.shared.propagate()
}

func testReduce() {
    var (x, tail) = Incremental.shared.list(from: [0,1,2,3])
    func tracedSum(x: Int, y: Int) -> Int {
        print("tracing sum: \((x, y))")
        return x + y
    }
    let reduced = Incremental.shared.reduce(isEqual: ==, x, 0, tracedSum)
    reduced.read { print($0) }
    Incremental.shared.propagate()
    
    tail.write(.cons(4, tail: I(.empty)))
    Incremental.shared.propagate()
    
}

struct Person: Equatable {
    let name: String
    let password: String

    static func ==(lhs: Person, rhs: Person) -> Bool {
        return lhs.name == rhs.name && lhs.password == rhs.password
    }
}


func testValidation() {
    let name = Var("")
    let validName: I<String?> = I(variable: name).mapE(==) { $0.isEmpty ? nil : $0 }

    let password = Var("a")
    let passwordRepeat = Var("b")

    let validPassword: I<String?> = I(variable: password).mapE(==) { $0.isEmpty ? nil : $0 }
    let successPassword: I<String?> = validPassword.zipE(I(variable: passwordRepeat), ==, { p1, p2 in
        //print("trace \(p1, p2, p1==p2)")
        return p1 == p2 ? p1 : nil
    })
    
//    let person: I<Person?> = validName.zipE(successPassword, ==) { oName, oPassword in
//        guard let name = oName, let password = oPassword else { return nil }
//        return Person(name: name, password: password)
//    }
    successPassword.read { p in
        print("Person: \(p)")
    }
    Incremental.shared.propagate()
    password.value = "one"
    passwordRepeat.value = "one"
    Incremental.shared.propagate()
}

func testArrayFilter() {
    let (arr, change) = Incremental.shared.array(initial: [0, 1, 2, 3, 4, 5])
    let filtered = Incremental.shared.filter(array: arr, condition: {
        print("trace: \($0)")
        return $0 % 2 == 0
    })
    filtered.latest.observe { i in
        print("latest: \(i)")
    }
    arr.latest.read { print("original: \($0)")}
    Incremental.shared.propagate()
    change(.append(6))
    change(.append(7))
    Incremental.shared.propagate()
}


func testArrayFilterSort() {
    let (arr, change) = Incremental.shared.array(initial: ["xx", "zero", "one", "two", "three", "four"])
    let filtered = Incremental.shared.filter(array: arr, condition: {
        return $0.characters.count > 2
    })
    let sorted = Incremental.shared.sort(array: filtered, String.comparator)
    sorted.latest.observe { i in
        print("latest: \(i)")
    }
    arr.latest.read { print("original: \($0)")}
    Incremental.shared.propagate()
    change(.append("hello world"))
    change(.append("x"))
    change(.remove(elementAt: 0))
    Incremental.shared.propagate()
}


// Todo:
// - IArray.sorted
// - IArray[0..<n] - independent slices

testArrayFilterSort()
testArrayFilter()
testValidation()
testReduce()
test()
test2()
testGui()
testArray()
testMinimal()
//
//
//

