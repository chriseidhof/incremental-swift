//
//  IncrementalDataStructures.swift
//  Incremental
//
//  Created by Chris Eidhof on 23.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

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
        func reduceH(_ list: I<IList<A>>, intermediate: Result, destination: I<Result>) {
            list.read {
                switch $0 {
                case .empty:
                    destination.write(intermediate)
                case .cons(let x, tail: let t):
                    reduceH(t, intermediate: transform(intermediate, x), destination: destination)
                }
            }
        }
        let destination: I<Result> = I(incremental: self, isEqual: isEqual)
        //destination.write(initial)        
        reduceH(list, intermediate: initial, destination: destination)
        return destination
    }
    
    func appending<Element>(list: I<IList<Element>>, element: Element) -> I<IList<Element>> {
        var destination: I<IList<Element>> = I(incremental: self)
        func appendingH(list: I<IList<Element>>, dest: I<IList<Element>>) {
            list.read { switch $0 {
            case .empty:
                dest.write(.cons(element, tail: self.constant(.empty)))
            case let .cons(x, tail: tail):
                let newDestination: I<IList<Element>> = I(incremental: self)
                appendingH(list: tail, dest: newDestination)
                dest.write(.cons(x, tail: newDestination))
            }}
        }
        appendingH(list: list, dest: destination)
        return destination
    }
    
    func array<Element: Equatable>(initial: [Element]) -> (IArray<Element>) {
        let x: [ArrayChange<Element>] = []
        let (changes, tail) = list(from: x)
        let latest: I<[Element]> = reduce(isEqual: ==, changes, initial, { arr, change in
            arr.applying(change: change)
        })
        var t = tail
        func appendChange(change: ArrayChange<Element>) {
            let newTail: I<IList<ArrayChange<Element>>> = self.constant(.empty)
            t.write(.cons(change, tail: newTail))
            t = newTail
        }
        return IArray(latest: latest, changes: changes, change: appendChange)
    }
}
