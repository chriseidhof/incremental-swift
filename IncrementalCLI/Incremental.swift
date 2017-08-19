//
//  Incremental.swift
//  Incremental
//
//  Created by Chris Eidhof on 23.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

final class References<A> {
    let freshInt: () -> Int
    typealias Token = Int
    var references: [Int:A] = [:]
    init() {
        var ints = (0...).makeIterator()
        freshInt = { ints.next()! }
    }
    
    @discardableResult
    func add(_ value: A) -> Token {
        let token = freshInt()
        references[token] = value
        return token
    }
    
    func remove(token: Token) {
        references[token] = nil
    }
    
    var values: AnySequence<A> {
        return AnySequence(references.values)
    }
}

public final class Var<A> {
    private let observers = References<(A) -> ()>()
    typealias Token = References<(A) -> ()>.Token
    
    public var value: A {
        didSet {
            for o in observers.values { o(value) }
        }
    }
    
    public init(_ value: A) {
        self.value = value
    }
    
    fileprivate func addObserver(x: @escaping (A) -> ()) -> Token {
        return observers.add(x)
    }
    
    fileprivate func removeObserver(token: Token) {
        observers.remove(token: token)
    }
    
}

// Todo: in reactive libraries, this would be called an observer...
final class Edge: Comparable, CustomDebugStringConvertible, CustomStringConvertible {
    var debugDescription: String {
        return "Edge<\(timeSpan), defined at \(file):\(line), source: \(source)>"
    }
    
    var description: String {
        return debugDescription
    }
    
    static func <(lhs: Edge, rhs: Edge) -> Bool {
        if lhs.timeSpan.start < rhs.timeSpan.start { return true }
        return rhs.timeSpan.end > rhs.timeSpan.end
    }
    
    static func ==(lhs: Edge, rhs: Edge) -> Bool {
        return lhs.timeSpan == rhs.timeSpan // not sure if this makes sense (we're not comparing reader)
    }
    
    let reader: () -> ()
    let timeSpan: (start: T, end: T)
    let line: UInt
    let file: StaticString
    weak var source: AnyObject?
    
    init(reader: @escaping () -> (), timeSpan: (start: T, end: T), line: UInt, file: StaticString, source: AnyObject?) {
        self.reader = reader
        self.timeSpan = timeSpan
        self.line = line
        self.file = file
        self.source = source
//        print("initing edge \(timeSpan)")
    }
    
    var isObserver: Bool {
        return timeSpan.start == timeSpan.end
    }
    
    deinit {
//        print("deiniting edge \(timeSpan)")
    }
}

protocol AnyI: class { }

public final class Disposable {
    private let dispose: () -> ()
    init(_ dispose: @escaping () -> ()) {
        self.dispose = dispose
    }
    deinit { dispose() }
}

public final class I<A>: AnyI {
    fileprivate var outEdges: [Edge] = []
    fileprivate let isEqual: (A, A) -> Bool

    // These can only be nil if no immediate write occurs (which is a programming error)
    var value: A!
    fileprivate var time: T! // Maybe this should be optional?
    fileprivate var constant: Bool = false
    
    // debugging
    fileprivate weak var parent: AnyI? // should be unowned or weak AnyI's
    fileprivate var line: UInt
    private var cleanup: [() -> ()] = []
    let strongReferences = References<Any>()
    
    public init(isEqual: @escaping (A, A) -> Bool, line: UInt = #line) {
        self.isEqual = isEqual
        self.line = line
    }
    // For memory debugging. Should be exactly the same as above (module deinit)
    init(isEqual: @escaping (A, A) -> Bool, line: UInt = #line, deinitializer: @escaping () -> ()) {
        self.isEqual = isEqual
        self.line = line
        self.cleanup.append(deinitializer)
    }

    public init(constant: A, line: UInt = #line) {
//        print("initing \(line)")
        self.isEqual = { _, _ in false }
        self.line = line
        self.write(constant: constant)
    }
    
    public init(isEqual: @escaping (A, A) -> Bool, value: A, line: UInt = #line) {
        self.line = line
        self.isEqual = isEqual
        self.write(value)
    }
    init(isEqual: @escaping (A, A) -> Bool, value: A, line: UInt = #line, deinitializer: @escaping () -> ()) {
        self.line = line
        self.isEqual = isEqual
        self.write(value)
        self.cleanup.append(deinitializer)
    }


    public func write(constant: A) {
        write(constant)
        self.constant = true
    }
    public func write(_ newValue: A) {
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
            //Incremental.shared.reading(self) {
                reader(self.value)
//            }
            let timespan = (start, Incremental.shared.currentTime)
            #if false
            if timespan.0 == timespan.1 {
                assertionFailure("You're using read to observe side-effects, use `observe` instead.", file: file, line: line)
            }
            #endif
            assert(timespan.0 <= timespan.1)
            let newEdge = Edge(reader: run, timeSpan: timespan, line: line, file: file, source: self)
            if let index = self.outEdges.index(where: { $0.timeSpan.start == timespan.0 && $0.timeSpan.end == timespan.1 }) {
                self.outEdges.remove(at: index)
            }
            //assert(!self.outEdges.contains(where: ), "Double edge with same timespan \(newEdge)")
            self.outEdges.append(newEdge)
        }
        cleanup.append { run = { fatalError() }} // run has a reference to the reader, we need to get rid of that
        run()
    }
    
    public func observe(line: UInt = #line, file: StaticString = #file, _ reader: @escaping (A) -> ()) -> Disposable {
        var start: T! = Incremental.shared.currentTime
        func run() {
            //start = Incremental.shared.freshTimeAfterCurrent()
            reader(value)
            assert(Incremental.shared.currentTime == start, "You're changing the graph in an observer. Use `read` or `write` instead.")
            outEdges.append(Edge(reader: run, timeSpan: (start: start, end: start), line: line, file: file, source: self))
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

    public func mapE<B>(_ isEqual: @escaping (B,B) -> Bool, _ transform: @escaping (A) -> B) -> I<B> {
        let result = I<B>(isEqual: isEqual)
        result.strongReferences.add(self)
        read { [unowned result] in
            result.write(transform($0))
        }
        return result
    }

    public func map<B>(_ transform: @escaping (A) -> B) -> I<B> where B: Equatable {
        return mapE(==, transform)
    }
    
    public func flatMap<B>(_ transform: @escaping (A) -> I<B>) -> I<B> where B: Equatable {
        let result = I<B>()
        result.strongReferences.add(self)
        var previous: References<Any>.Token? = nil
        read { [unowned result] value in
            if let token = previous {
                result.strongReferences.remove(token: token)
            }
            let nested = transform(value)
            previous = result.strongReferences.add(nested)
            nested.read { [unowned result] newValue in
                result.write(newValue)
            }
        }
        return result
    }
    
    public func zipE<B,C>(_ r: I<B>, _ isEqual: @escaping (C,C) -> Bool, _ transform: @escaping (A, B) -> C) -> I<C> {
        let result = I<C>(isEqual: isEqual)
        result.strongReferences.add(self)
        result.strongReferences.add(r)
        self.read { [unowned result, r] value1 in
            r.read { [unowned result] value2 in
                result.write(transform(value1, value2))
            }
        }
        return result
    }
    
    public func zip<B,C>(_ r: I<B>, _ transform: @escaping (A, B) -> C) -> I<C> where C: Equatable {
        let result = zipE(r, ==, transform)
        result.cleanup.append {
            print("removing zip")
        }
        return result
    }
    
    deinit {
        cleanup.forEach { $0() }
//        print("Deiniting \(self) [\(line)]")
    }
}

extension I: Equatable {
    public static func ==(lhs: I, rhs: I) -> Bool {
        return lhs === rhs
    }
}

extension I where A: Equatable {
    convenience init(line: UInt = #line) {
        self.init(isEqual: ==, line: line)
    }
    
    // this is for testing memory
    convenience init(variable: Var<A>, line: UInt = #line, deinitializer: @escaping () -> ()) {
        self.init(value: variable.value, line: line, deinitializer: deinitializer)
        let token = variable.addObserver { [unowned self] newValue in
            self.write(newValue)
        }
        cleanup.append { variable.removeObserver(token: token) }
    }
    public convenience init(variable: Var<A>, line: UInt = #line) {
        self.init(value: variable.value, line: line)
        let token = variable.addObserver { [unowned self] newValue in
            self.write(newValue)
        }
        cleanup.append { variable.removeObserver(token: token) }
    }
    
    public convenience init(value: A, line: UInt = #line, deinitializer: @escaping () -> ()) {
        self.init(isEqual: ==, value: value, line: line, deinitializer: deinitializer)
    }
    public convenience init(value: A, line: UInt = #line) {
        self.init(isEqual: ==, value: value, line: line)
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

public final class Incremental {
    var clock = Clock()
    var currentTime: T
    var queue = SortedArray<Edge>(unsorted: [])
    public static let shared = Incremental()
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
    
    public func propagate() {
        let theTime = currentTime
        while !queue.isEmpty {
            let edge = queue.remove(at: 0)
            guard clock.contains(t: edge.timeSpan.start) else {
                continue
            }
            assert(!queue.contains(where: { $0.timeSpan.start == edge.timeSpan.start && $0.timeSpan.end == edge.timeSpan.end && !$0.isObserver }), "Double edge: \(edge)")
            clock.delete(between: edge.timeSpan.start, and: edge.timeSpan.end)
            queue.remove(where: { $0.timeSpan.start > edge.timeSpan.start && $0.timeSpan.start < edge.timeSpan.end})
            currentTime = edge.timeSpan.start
            edge.reader()
        }
        currentTime = theTime
    }
}
