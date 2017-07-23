//
//  Clock.swift
//  Incremental
//
//  Created by Chris Eidhof on 22.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

struct T: Comparable, Hashable {
    var hashValue: Int {
        return time.hashValue
    }
    
    static func <(lhs: T, rhs: T) -> Bool {
        return lhs.time < rhs.time
    }
    
    static func ==(lhs: T, rhs: T) -> Bool {
        return lhs.time == rhs.time
    }
    
    /*fileprivate*/ let time: Double
}

// Todo: this can be implemented more efficiently
struct Clock {
    private var backing: SortedArray<T> = SortedArray(unsorted: [T(time: 0.0)])
    var initial: T {
        return T.init(time: 0)
    }
    
    func compare(l: T, r: T) -> Bool {
        return l.time < r.time
    }
    
    mutating func insert(after: T) -> T {
        guard let index = backing.index(of: after) else {
            let b = backing.map { "\($0.time)" }.joined(separator: ",")
            fatalError("backing: \(b), after: \(after)")
        }
        let newTime: T
        let nextIndex = backing.index(after: index)
        if nextIndex == backing.endIndex {
            newTime = T(time: after.time + 10)
        } else {
            let nextValue = backing[nextIndex]
            newTime = T(time: (after.time + nextValue.time)/2)
        }
        backing.insert(newTime)
        return newTime
    }
    
    mutating func delete(between from: T, and to: T) {
        assert(from.time <= to.time, "\(from.time) <= \(to.time))")
        backing.remove(where: { $0 > from && $0 < to})
    }
    
    func contains(t: T) -> Bool {
        return backing.contains(t)
    }
}
