//
//  main.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

// Todo: in reactive libraries, this would be called an observer...
struct Edge: Comparable, CustomDebugStringConvertible, CustomStringConvertible {
    var debugDescription: String {
        return "Edge<\(timeSpan)>"
    }
    
    var description: String {
        return debugDescription
    }
    
    static func <(lhs: Edge, rhs: Edge) -> Bool {
        if lhs.timeSpan.start < rhs.timeSpan.start { return true }
        return rhs.timeSpan.start < rhs.timeSpan.start
    }
    
    static func ==(lhs: Edge, rhs: Edge) -> Bool {
        return lhs.timeSpan == rhs.timeSpan // not sure if this makes sense (we're not comparing reader)
    }
    
    let reader: () -> ()
    let timeSpan: (start: T, end: T)
}

final class I<A> {
    unowned var incremental: Incremental
    fileprivate var outEdges: [Edge] = []
    fileprivate var value: (() -> A)?
    fileprivate var time: T?
    let isEqual: (A, A) -> Bool
    
    fileprivate init(incremental: Incremental, isEqual: @escaping (A, A) -> Bool, value: (() -> A)? = nil) {
        self.incremental = incremental
        self.value = value
        self.isEqual = isEqual
    }
    
    fileprivate func write(_ newValue: A) {
        guard let time = time else {
            value = { newValue }
            self.time = incremental.freshTimeAfterCurrent()
            return
        }
        
        if let v = value {
            guard !isEqual(v(), newValue) else { return }
        }
        value = { newValue }
        incremental.enqueue(edges: outEdges)
        outEdges = []
        incremental.currentTime = time
    }
    
    fileprivate func read(_ reader: @escaping (A) -> ()) {
        let start = incremental.freshTimeAfterCurrent()
        func run() {
            let v = value!()
            reader(v)
            let timespan = (start, incremental.currentTime)
            outEdges.append(Edge(reader: run, timeSpan: timespan))
        }
        run()
    }
    
    func map<B>(_ transform: @escaping (A) -> B) -> I<B> where B: Equatable {
        let result = I<B>(incremental: incremental)
        read {
            result.write(transform($0))
        }
        return result
    }
    
    func flatMap<B>(_ transform: @escaping (A) -> I<B>) -> I<B> where B: Equatable {
        let result = I<B>(incremental: incremental)
        read { value in
            transform(value).read { newValue in
                result.write(newValue)
            }
        }
        return result
    }
    
    func zip<B,C>(_ r: I<B>, _ transform: @escaping (A, B) -> C) -> I<C> where C: Equatable {
        let result = I<C>(incremental: incremental)
        read { value1 in
            r.read { value2 in
                result.write(transform(value1, value2))
            }
        }
        return result
    }
}

extension I where A: Equatable {
    convenience init(incremental: Incremental) {
        self.init(incremental: incremental, isEqual: ==)
    }
}

final class Var<A> {
    var value: A {
        didSet {
            for o in observers { o(value) }
        }
    }
    private var observers: [(A) -> ()] = []

    init(_ value: A) {
        self.value = value
    }
    
    fileprivate func addObserver(x: @escaping (A) -> ()) { // todo remove
        observers.append(x)
    }
}

final class Observer<A: Equatable> {
    init(_ i: I<A>) {
    }
    
    var value: A {
        fatalError()
    }
    
    func onUpdate(_ f: (A) -> ()) {
    }
    
    func stopObserving() { }
}

final class Incremental {
    var clock = Clock()
    var currentTime: T
    var queue = SortedArray<Edge>(unsorted: [])
    
    init() {
        currentTime = clock.initial
    }
    
    fileprivate func enqueue(edges: [Edge]) {
        queue.insert(contentsOf: edges)
    }
    
    fileprivate func freshTimeAfterCurrent() -> T {
        currentTime = clock.insert(after: currentTime)
        return currentTime
    }
    
    func constant<A>(_ value: A) -> I<A> where A: Equatable {
        let result = I<A>(incremental: self)
        result.write(value)
        return result
    }
    
    func read<A>(_ variable: Var<A>) -> I<A> where A: Equatable {
        let result = I<A>(incremental: self)
        variable.addObserver { newValue in // todo: should the variable strongly reference the result? probably not
            result.write(newValue)
        }
        result.write(variable.value)
        return result
    }
    
    func propagate() {
        let theTime = currentTime
        while !queue.isEmpty {
            let edge = queue.remove(at: 0)
            guard clock.contains(t: edge.timeSpan.start) else {
                continue
            }
            clock.delete(between: edge.timeSpan.start, and: edge.timeSpan.end)
            currentTime = edge.timeSpan.start
            edge.reader()
        }
        currentTime = theTime
    }
}

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

enum ArrayChange<Element>: Equatable where Element: Equatable {
    case insert(element: Element, at: Int)
    case remove(elementAt: Int)
    case append(Element)
    
    static func ==(lhs: ArrayChange<Element>, rhs: ArrayChange<Element>) -> Bool {
        switch (lhs, rhs) {
        case (.insert(let e1, let a1), .insert(let e2, let a2)):
            return e1 == e2 && a1 == a2
        case (.remove(let i1), .remove(let i2)):
            return i1 == i2
        case (.append(let e), .append(let e2)):
            return e == e2
        default:
            return false
        }
    }
}

extension Array where Element: Equatable {
    func applying(change: ArrayChange<Element>) -> [Element] {
        var copy = self
        copy.apply(change: change)
        return copy
    }
    mutating func apply(change: ArrayChange<Element>) {
        switch change {
        case let .insert(element: e, at: i):
            self.insert(e, at: i)
        case .remove(elementAt: let i):
            self.remove(at: i)
        case .append(element: let i):
            self.append(i)
        }
    }
}

indirect enum IList<A: Equatable>: Equatable {
    case empty
    case cons(A, tail: I<IList<A>>)
    
    static func ==(lhs: IList, rhs: IList) -> Bool {
        if case .empty = lhs, case .empty = rhs { return true }
        return false
    }
}

struct IArray<Element: Equatable> {
//    let initial: [Element]
    let latest: I<[Element]>
    let changes: I<IList<ArrayChange<Element>>>
    let change: (ArrayChange<Element>) -> ()
}

extension Incremental {
    func list<S: Sequence, Element>(from sequence: S) -> (I<IList<Element>>, I<IList<Element>>) where S.Iterator.Element == Element, Element: Equatable {
        let tail: I<IList<Element>> = self.constant(.empty)
        var result: I<IList<Element>> = tail
        for item in sequence {
            result = self.constant(.cons(item, tail: result))
        }
        
        return (result, tail)
    }
    
    func reduce<A, Result>(isEqual: @escaping (Result, Result) -> Bool, _ list: I<IList<A>>, _ initial: Result, _ transform: @escaping (Result, A) -> Result) -> I<Result> {
        let destination: I<Result> = I(incremental: self, isEqual: isEqual)

        func reduceH(_ list: I<IList<A>>, intermediate: Result) {
            list.read {
                switch $0 {
                case .empty:
                    destination.write(intermediate)
                case .cons(let x, tail: let t):
                    reduceH(t, intermediate: transform(intermediate, x))
                }
            }
        }
        reduceH(list, intermediate: initial)
        return destination
    }
    
    func array<Element: Equatable>(initial: [Element]) -> (IArray<Element>) {
        let x: [ArrayChange<Element>] = []
        let (changes, tail) = list(from: x)
        let latest: I<[Element]> = reduce(isEqual: ==, changes, initial, { arr, change in
            arr.applying(change: change)
        })
        var t = tail
        func appendChange(el: ArrayChange<Element>) {
            let newTail: I<IList<ArrayChange<Element>>> = constant(.empty)
            t.write(.cons(el, tail: newTail))
            t = newTail
        }
        return IArray(latest: latest, changes: changes, change: appendChange)
    }
}

func if_<A: Equatable>(_ cond: I<Bool>, _ then: @autoclosure @escaping () -> I<A>, else alt:  @autoclosure @escaping () -> I<A>) -> I<A> {
    return cond.flatMap { $0 ? then() : alt() }
}

func testArray() {
    let arr = inc.array(initial: [] as [Int])
    let size: I<String> = if_(arr.latest.map { $0.count > 1 }, inc.constant("large"), else: inc.constant("small"))
    size.read { print($0) }
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

    gui.read { print($0) }

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
    sum.read { print("result: \($0)") }
    inc.propagate()
    print("propagated")
    
    x.value = 10
    y.value = 20
    inc.propagate()
    print("Done")
}

//test()
//testGui()
testArray()

