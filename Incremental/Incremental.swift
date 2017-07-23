//
//  Incremental.swift
//  Incremental
//
//  Created by Chris Eidhof on 23.07.17.
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
    var outEdges: [Edge] = []
    var value: (() -> A)?
    var time: T?
    let isEqual: (A, A) -> Bool
    
    init(incremental: Incremental, isEqual: @escaping (A, A) -> Bool, value: (() -> A)? = nil) {
        self.incremental = incremental
        self.value = value
        self.isEqual = isEqual
    }
    
    func write(_ newValue: A) {
        guard let time = time else { // initial write
            value = { newValue }
            self.time = incremental.freshTimeAfterCurrent()
            return
        }
        
        if !isEqual(value!(), newValue) {
            value = { newValue }
            incremental.enqueue(edges: outEdges)
            outEdges = []
        }
        
        incremental.currentTime = time
    }
    
    func read(_ reader: @escaping (A) -> ()) {
        let start = incremental.freshTimeAfterCurrent()
        func run() {
            reader(value!())
            let timespan = (start, incremental.currentTime)
            assert(timespan.0 <= timespan.1)
            outEdges.append(Edge(reader: run, timeSpan: timespan))
        }
        run()
    }
    
    func observe(_ reader: @escaping (A) -> ()) {
        func run() {
            reader(value!())
            outEdges.append(Edge(reader: run, timeSpan: (start: incremental.currentTime, end: incremental.currentTime)))
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

extension I: Equatable {
    static func ==(lhs: I, rhs: I) -> Bool {
        return lhs === rhs
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
