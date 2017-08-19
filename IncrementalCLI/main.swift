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


//testArray()

enum MyApp {
    case loginScreen
    case product(productId: Int)
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

    let observer = gui.observe {
        print($0)
    }

    counter.value += 1

    Incremental.shared.propagate()

    print("propagated")
    app.value = .other(strI)
    counter.value = 3

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
        return p1 == p2 ? p1 : nil
    })
    
//    let person: I<Person?> = validName.zipE(successPassword, ==) { oName, oPassword in
//        guard let name = oName, let password = oPassword else { return nil }
//        return Person(name: name, password: password)
//    }
    let observer = successPassword.observe { p in
        print("Person: \(p)")
    }
    Incremental.shared.propagate()
    password.value = "one"
    passwordRepeat.value = "one"
    Incremental.shared.propagate()
}

func simplestExample() {
    let x = Var(5)
    let y = Var(6)
    let z = I<Int>()
    let x1 = I(variable: x)
    let y1 = I(variable: y)
    
    // At this point, x1 has time 10, y1 has time 20, and z does not have a time yet (because it isn't written to)
    
    x1.read { xVal in
        // the current time is 30
        y1.read { yVal in
            // the current time is 40
            // writing will set the time of z to a new, fresh time: 50
            z.write(xVal + yVal)
        }
    }
    
    var observer: Any? = z.observe { x in print(x) } // this reader adds time 60
    Incremental.shared.propagate() // nothing to propagate
    
    y.value = 11 // this adds y1's read block to the queue. the timespan of that block is 40-50
    x.value = 10 // this adds x1's read block to the queue. x's read block has timespan 30-50
    
    // the queue contains two blocks: 30-50 and 40-50.
    // The fact that the start time of the second block is within the timespan of the first block means that the second block is contained within the first block.
    // The moment we process the first block, we can remove all other blocks
    Incremental.shared.propagate()
    observer = nil
    x.value = 20
    Incremental.shared.propagate()
}

func garbageCollectionSmall() {
    let tmp = I<Int>()
    tmp.write(5)
    let out = I<Int>()
    tmp.read {
        out.write($0 + 1)
    }
    var x: Any? = tmp.observe { x in print(x) }
    Incremental.shared.propagate()
    print("done")
}

func garbageCollectionLarger() {
    var (tmp, change) = Incremental.shared.array(initial: [0,1,2])
    change(.append(3))
    Incremental.shared.reduce(isEqual: { _, _ in true }, tmp.changes, (), { _, change in
        print(change)
        return ()
    })
    Incremental.shared.propagate()
//    tmp.write(5)
//    let out = I<Int>()
//    tmp.read {
//        out.write($0 + 1)
//    }
//    var x: Any? = tmp.observe { x in print(x) }
//    Incremental.shared.propagate()
    print("done")
    
}


func binaryTreeExample() {
    let x: I<IBinaryTree<Int>> = I(value: .empty)
//    let inOrder: I<[Int]> = reduceWith(isEqual: ==, x, empty: [], combine: { (value: Int, l: [Int], r: [Int]) in
//        print("combining \(l) \(value) and \(r)")
//        return l + [value] + r
//    })
//    let observer1 = inOrder.observe {
//        assert($0.sorted() == $0)
//        print($0)
//    }
    let binaryTree: I<BinaryTree<Int>> = reduceWith(isEqual: ==, x, empty: .empty, combine: { v, l, r in
        return .node(v, left: l, right: r)
    })
    let observer2 = binaryTree.observe { value in print(value) }
    for value in [8,5,6,7,3,2,3] {
        unsafeInsert(x, value)
        Incremental.shared.propagate()
    }
}