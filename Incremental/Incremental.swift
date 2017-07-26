//
//  Incremental.swift
//  Incremental
//
//  Created by Chris Eidhof on 23.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

// Todo: in reactive libraries, this would be called an observer...
final class Edge: Comparable, CustomDebugStringConvertible, CustomStringConvertible {
    var debugDescription: String {
        return "Edge<\(timeSpan)>"
    }
    
    var description: String {
        return debugDescription
    }
    
    static func <(lhs: Edge, rhs: Edge) -> Bool {
        if lhs.timeSpan.start < rhs.timeSpan.start { return true }
        return rhs.timeSpan.start > rhs.timeSpan.start
    }
    
    static func ==(lhs: Edge, rhs: Edge) -> Bool {
        return lhs.timeSpan == rhs.timeSpan // not sure if this makes sense (we're not comparing reader)
    }
    
    let reader: () -> ()
    let timeSpan: (start: T, end: T)
    
    init(reader: @escaping () -> (), timeSpan: (start: T, end: T)) {
        self.reader = reader
        self.timeSpan = timeSpan
//        print("initing edge \(timeSpan)")
    }
    
    deinit {
//        print("deiniting edge \(timeSpan)")
    }
}

protocol AnyI: class {
    
}

final class Disposable {
    private let dispose: () -> ()
    init(_ dispose: @escaping () -> ()) {
        self.dispose = dispose
    }
    deinit { dispose() }
}

final class I<A>: AnyI {
    var outEdges: [Edge] = []
    let isEqual: (A, A) -> Bool

    // These can only be nil if no immediate write occurs (which is a programming error)
    var value: A!
    var time: T! // Maybe this should be optional?
    var constant: Bool = false
    
    // debugging
    weak var parent: AnyI? // should be unowned or weak AnyI's
    var line: UInt
    private var cleanup: [() -> ()] = []
    
    init(isEqual: @escaping (A, A) -> Bool, line: UInt = #line) {
        print("initing i [\(line)]")
        self.isEqual = isEqual
        self.line = line
    }
    
    init(constant: A, line: UInt = #line) {
        print("initing \(line)")
        self.isEqual = { _, _ in false }
        self.line = line
        self.write(constant: value)
    }
    

    func write(constant: A) {
        write(constant)
        self.constant = true
    }
    func write(_ newValue: A) {
        assert(!constant, "writing to constant declared at line \(line)")
        
        guard let time = time else { // initial write
            value = newValue
            self.time = Incremental.shared.freshTimeAfterCurrent()
            parent = Incremental.shared.reads.last
            return
        }
        
        if !isEqual(value, newValue) {
            value = newValue
            Incremental.shared.enqueue(edges: outEdges)
            outEdges = []
        }
        
        Incremental.shared.currentTime = time
    }
    
    func read(file: StaticString = #file, line: UInt = #line, _ reader: @escaping (A) -> ()) {
        guard !constant else {
            reader(value)
            return
        }
        let start = Incremental.shared.freshTimeAfterCurrent()
        var run: () -> () = { fatalError() }
        run = { [unowned self] in
            assert(self.value != nil, "Read before write", file: file, line: line)
            Incremental.shared.reading(self) {
                reader(self.value)
            }
            let timespan = (start, Incremental.shared.currentTime)
            if timespan.0 == timespan.1 {
                assertionFailure("You're using read to observe side-effects, use `observe` instead.", file: file, line: line)
            }
            assert(timespan.0 <= timespan.1)
            self.outEdges.append(Edge(reader: run, timeSpan: timespan))
        }
        cleanup.append { run = { fatalError() }} // run has a reference to the reader, we need to get rid of that
        run()
    }
    
    func observe(_ reader: @escaping (A) -> ()) -> Disposable {
        var start: T!
        func run() {
            start = Incremental.shared.freshTimeAfterCurrent()
            reader(value)
            assert(Incremental.shared.currentTime == start, "You're changing the graph in an observer. Use `read` or `write` instead.")
            outEdges.append(Edge(reader: run, timeSpan: (start: start, end: start)))
        }
        run()
        return Disposable { [unowned self] in
            self.removeEdge(time: start)
        }
    }
    
    func removeEdge(time: T) {
        if let index = outEdges.index(where: { $0.timeSpan.start == time }) {
            outEdges.remove(at: index)
        } else {
            Incremental.shared.removeEdge(start: time)
        }
    }

    func mapE<B>(_ isEqual: @escaping (B,B) -> Bool, _ transform: @escaping (A) -> B) -> I<B> {
        let result = I<B>(isEqual: isEqual)
        read {
            result.write(transform($0))
        }
        return result
    }

    func map<B>(_ transform: @escaping (A) -> B) -> I<B> where B: Equatable {
        return mapE(==, transform)
    }
    
    func flatMap<B>(_ transform: @escaping (A) -> I<B>) -> I<B> where B: Equatable {
        let result = I<B>()
        read { value in
            transform(value).read { newValue in
                result.write(newValue)
            }
        }
        return result
    }
    
    func zipE<B,C>(_ r: I<B>, _ isEqual: @escaping (C,C) -> Bool, _ transform: @escaping (A, B) -> C) -> I<C> {
        let result = I<C>(isEqual: isEqual)
        read { value1 in
            r.read { value2 in
                result.write(transform(value1, value2))
            }
        }
        return result
    }
    
    func zip<B,C>(_ r: I<B>, _ transform: @escaping (A, B) -> C) -> I<C> where C: Equatable {
        return zipE(r, ==, transform)
    }
    
    deinit {
        cleanup.forEach { $0() }
        print("Deiniting \(self) [\(line)]")
    }
}

extension I: Equatable {
    static func ==(lhs: I, rhs: I) -> Bool {
        return lhs === rhs
    }
}

extension I where A: Equatable {
    convenience init(line: UInt = #line) {
        self.init(isEqual: ==, line: line)
    }
    
    convenience init(_ constant: A, line: UInt = #line) {
        self.init(constant: constant, line: line)
    }
    
    convenience init(variable: Var<A>, line: UInt = #line) {
        self.init(variable.value, line: line)
        variable.addObserver { [weak self] newValue in
            self?.write(newValue)
        }
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
    static let shared = Incremental()
    private(set) var reads: [AnyI] = []
    
    private init() {
        currentTime = clock.initial
    }
    
    fileprivate func enqueue(edges: [Edge]) {
        queue.insert(contentsOf: edges)
    }
    
    fileprivate func freshTimeAfterCurrent() -> T {
        currentTime = clock.insert(after: currentTime)
        return currentTime
    }
    
    func reading(_ i: AnyI, _ reader: () -> ()) {
        reads.append(i)
        reader()
        reads.removeLast()
    }
    
    func removeEdge(start: T) {
        guard let index = queue.index(where: { $0.timeSpan.start == start }) else {
            fatalError("Trying to remove a non-existent edge")
        }
        _ = queue.remove(at: index)
    }
    
    func propagate() {
        let theTime = currentTime
        while !queue.isEmpty {
            let edge = queue.remove(at: 0)
            guard clock.contains(t: edge.timeSpan.start) else {
                continue
            }
            clock.delete(between: edge.timeSpan.start, and: edge.timeSpan.end)
            queue.remove(where: { $0.timeSpan.start > edge.timeSpan.start && $0.timeSpan.start < edge.timeSpan.end})
            currentTime = edge.timeSpan.start
            edge.reader()
        }
        currentTime = theTime
    }
}
