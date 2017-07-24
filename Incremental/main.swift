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
    let (arr, change) = inc.array(initial: [] as [Int])
    let latest: I<[Int]> = inc.reduce(isEqual: ==, arr.changes, arr.initial) { l, el in
        l.applying(change: el)
    }

    let size: I<String> = if_(latest.map { $0.count > 1 }, inc.constant("large"), else: inc.constant("small"))
    size.observe {
        print($0)
    }
    change(.append(4))
    inc.propagate()
    change(.append(5))
    change(.insert(element: 0, at: 0))
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

func test2() {
    let x = Var(5)
    let sum = inc.read(x).zip(inc.read(x), +)
    sum.read {
        print("sum: \($0)")
    }
    inc.propagate()
    x.value = 6
    inc.propagate()
}

func testReduce() {
    var (x, tail) = inc.list(from: [0,1,2,3])
    func tracedSum(x: Int, y: Int) -> Int {
        print("tracing sum: \((x, y))")
        return x + y
    }
    let reduced = inc.reduce(isEqual: ==, x, 0, tracedSum)
    reduced.read { print($0) }
    inc.propagate()
    
    tail.write(.cons(4, tail: inc.constant(.empty)))
    inc.propagate()
    
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
    let validName: I<String?> = inc.read(name).mapE(==) { $0.isEmpty ? nil : $0 }

    let password = Var("a")
    let passwordRepeat = Var("b")

    let validPassword: I<String?> = inc.read(password).mapE(==) { $0.isEmpty ? nil : $0 }
    let successPassword: I<String?> = validPassword.zipE(inc.read(passwordRepeat), ==, { p1, p2 in
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
    inc.propagate()
    password.value = "one"
    passwordRepeat.value = "one"
    inc.propagate()
}

func testArrayFilter() {
    let (arr, change) = inc.array(initial: [0, 1, 2, 3, 4, 5])
    let filtered = inc.filter(array: arr, condition: {
        print("trace: \($0)")
        return $0 % 2 == 0
    })
    filtered.latest.observe { i in
        print("latest: \(i)")
    }
    arr.latest.read { print("original: \($0)")}
    inc.propagate()
    change(.append(6))
    change(.append(7))
    inc.propagate()
}

// Todo:
// - IArray.sorted
// - IArray[0..<n] - independent slices

testArrayFilter()
//testValidation()
//testReduce()
//test()
//test2()
//testGui()
//testArray()
//testMinimal()
//
//
//

