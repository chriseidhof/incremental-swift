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
//
//func lift<Element: Equatable>(_ isIncluded: (Element) -> Bool) -> (ArrayChange<Element>) -> Bool {
//    return { c in
//        switch c {
//        case let .insert(element, at: index):
//            return isIncluded(element)
//            case
//        }
//    }
//}

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

struct IArray<Element: Equatable>: Equatable {
    let initial: [Element]
    let changes: I<IList<ArrayChange<Element>>>
    
    var latest: I<[Element]> {
        return Incremental.shared.reduce(isEqual: ==, changes, initial) { l, el in
            l.applying(change: el)
        }
    }
}

func ==<A>(lhs: IArray<A>, rhs: IArray<A>) -> Bool {
    return false
}

extension Incremental {
    /// A constant list: you are only allowed to append (using the second result parameter)
    func list<S: Sequence, Element>(from sequence: S) -> (I<IList<Element>>, I<IList<Element>>) where S.Iterator.Element == Element, Element: Equatable {
        let tail: I<IList<Element>> = I()
        var result: I<IList<Element>> = tail
        for item in sequence.reversed() {
            result = I(constant: .cons(item, tail: result))
        }
        tail.write(.empty)
        
        return (result, tail)
    }
    
    func reduce<A, Result>(isEqual: @escaping (Result, Result) -> Bool, _ list: I<IList<A>>, _ initial: Result, _ transform: @escaping (Result, A) -> Result) -> I<Result> {
        func reduceH(_ list: I<IList<A>>, intermediate: Result, destination: I<Result>) {
            destination.strongReferences.add(list)
            list.read { [unowned destination] in
                switch $0 {
                case .empty:
                    destination.write(intermediate)
                case .cons(let x, tail: let t):
                    reduceH(t, intermediate: transform(intermediate, x), destination: destination)
                }
            }
        }
        let destination: I<Result> = I(isEqual: isEqual)
        reduceH(list, intermediate: initial, destination: destination)
        return destination
    }
    
    func appending<Element>(list: I<IList<Element>>, element: Element) -> I<IList<Element>> {
        func appendingH(list: I<IList<Element>>, dest: I<IList<Element>>) {
            dest.strongReferences.add(list)
            list.read { [unowned dest] in switch $0 {
            case .empty:
                let tail = I<IList<Element>>(value: IList.empty)
                dest.write(IList<Element>.cons(element, tail: tail))
            case let .cons(x, tail: tail):
                let newDestination: I<IList<Element>> = I()
                appendingH(list: tail, dest: newDestination)
                dest.write(.cons(x, tail: newDestination))
            }}
        }
        let destination: I<IList<Element>> = I()
        appendingH(list: list, dest: destination)
        return destination
    }
    
    func array<Element: Equatable>(initial: [Element]) -> (IArray<Element>, change: (ArrayChange<Element>) -> ()) {
        let x: [ArrayChange<Element>] = []
        var (changes, tail) = list(from: x)
        func appendChange(change: ArrayChange<Element>) {
            let newTail: I<IList<ArrayChange<Element>>> = I()
            newTail.write(.empty)
            tail.write(constant: .cons(change, tail: newTail))
            tail = newTail
        }
        return (IArray(initial: initial, changes: changes), appendChange)
    }
    
    func filter<Element>(list: I<IList<Element>>, _ condition: @escaping (Element) -> Bool) -> I<IList<Element>> {
        func recurse(list: I<IList<Element>>, destination: I<IList<Element>>) {
            destination.strongReferences.add(list)
            list.read { [unowned destination] l in
                switch l {
                case .empty:
                    destination.write(.empty)
                case let .cons(el, tail: t):
                    if condition(el) {
                        let newTail: I<IList<Element>> = I()
                        destination.write(.cons(el, tail: newTail))
                        recurse(list: t, destination: newTail)
                    } else {
                        recurse(list: t, destination: destination)
                    }
                }
            }
        }
        let dest: I<IList<Element>> = I()
        recurse(list: list, destination: dest)
        return dest
    }
    
    // Todo abstract out the duplication between `filter` and `sort`.
    func filter<Element>(array: IArray<Element>, condition: @escaping (Element) -> Bool) -> IArray<Element> {
        var initial = array.initial.filter(condition)
        let filteredChanges: I<IList<ArrayChange<Element>>> = I(isEqual: ==)
        func filterH(changes: I<IList<ArrayChange<Element>>>, destination: I<IList<ArrayChange<Element>>>, current: [Element]) {
            destination.strongReferences.add(changes)
            changes.read { [unowned destination] in switch $0 {
            case .empty:
                destination.write(.empty)
            case let .cons(change, tail: tail):
                if let result = current.applying(change: change, for: condition) {
                    let newTail: I<IList<ArrayChange<Element>>> = I(isEqual: ==)
                    destination.write(.cons(change, tail: newTail))
                    filterH(changes: tail, destination: newTail, current: result)
                } else {
                    filterH(changes: tail, destination: destination, current: current)
                }
            }}
        }
        filterH(changes: array.changes, destination: filteredChanges, current: initial)
        return IArray(initial: initial, changes: filteredChanges)
    }
    
    func sort<Element>(array: IArray<Element>, _ sortDescriptor: @escaping (Element,Element) -> ComparisonResult) -> IArray<Element> {
        let changes: I<IList<ArrayChange<Element>>> = I(isEqual: ==)
        func sortH(changes: I<IList<ArrayChange<Element>>>, destination: I<IList<ArrayChange<Element>>>, array: [Element], current: SortedArray<Element>) {
            var copy = current
            destination.strongReferences.add(changes)
            changes.read { [unowned destination] in switch $0 {
            case .empty: destination.write(.empty)
            case let .cons(change, tail: tail):
                let newTail: I<IList<ArrayChange<Element>>> = I(isEqual: ==)
                let newChange: ArrayChange<Element>
                switch change {
                case .append(let el):
                    newChange = .insert(element: el, at: copy.insert(el))
                case let .insert(element: element, at: _):
                    newChange = .insert(element: element, at: copy.insert(element))
                case .remove(elementAt: let i):
                    let element = array[i]
                    let index = copy.index(of: element)!
                    _ = copy.remove(at: index)
                    newChange = .remove(elementAt: index)
                }
                
                destination.write(.cons(newChange, tail: newTail))
                sortH(changes: tail, destination: newTail, array: array.applying(change: change), current: copy)
            }}
        }
        let sorted = SortedArray(unsorted: array.initial, sortDescriptor: sortDescriptor)
        sortH(changes: array.changes, destination: changes, array: array.initial, current: sorted)
        return IArray(initial: sorted.elements, changes: changes)
    }
}

extension Array where Element: Equatable {
    func applying(change: ArrayChange<Element>, for condition: (Element) -> Bool) -> [Element]? {
        switch change {
        case .append(let x):
            return condition(x) ? applying(change: change) : nil
        case .insert(element: let el, at: _):
            return condition(el) ? applying(change: change) : nil
        case .remove(elementAt: let i):
            return condition(self[i]) ? applying(change: change) : nil
        }
    }
}
