//
//  BinaryTree.swift
//  Incremental
//
//  Created by Chris Eidhof on 27.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import Foundation

enum BinaryTree<Element: Comparable>: Equatable {
    case empty
    indirect case node(Element, left: BinaryTree, right: BinaryTree)
    
    static func ==(lhs: BinaryTree, rhs: BinaryTree) -> Bool {
        switch (lhs,rhs) {
        case (.empty, .empty):
            return true
        case let (.node(v1, l1, r1), .node(v2, l2, r2)):
            return v1 == v2 && l1 == l2 && r1 == r2
        default:
            return false
        }
    }
}

extension BinaryTree {
    func reduce<Result>(_ zero: Result, _ combine: (Element, Result, Result) -> Result, write: (Result) -> ())  {
        switch self {
        case .empty:
            write(zero)
        case let .node(value, left: l, right: r):
            l.reduce(zero, combine) { l1 in
                r.reduce(zero, combine) { r1 in
                    write(combine(value, l1, r1))
                }
            }
        }
    }
}

extension BinaryTree: CustomStringConvertible {
    var description: String {
        switch self {
        case .empty:
            return "()"
        case let .node(element, .empty, .empty):
            return "(\(element))"
        case let .node(element, left, right):
            return "(\(left) \(element) \(right))"
        }
    }
}


enum IBinaryTree<Element: Comparable>: Equatable {
    case empty
    indirect case node(Element, left: I<IBinaryTree<Element>>, right: I<IBinaryTree<Element>>)
    
    static func ==(lhs: IBinaryTree, rhs: IBinaryTree) -> Bool {
        switch (lhs, rhs) {
        case (.empty, .empty): return true
        default: return false
        }
    }
}


func inserting<Element>(_ tree: I<IBinaryTree<Element>>, newElement: Element) -> I<IBinaryTree<Element>> {
    let destination: I<IBinaryTree<Element>> = I()
    tree.read { switch $0 {
    case .empty:
        destination.write(.node(newElement, left: I(value: .empty), right: I(value: .empty)))
    case let .node(element, left: left, right: right):
        if element < newElement {
            destination.write(IBinaryTree<Element>.node(element, left: left, right: inserting(right, newElement: newElement)))
        } else {
            destination.write(IBinaryTree<Element>.node(element, left: inserting(left, newElement: newElement), right: right))
        }
        }}
    return destination
}

func reduceWith<Element, Result>(isEqual: @escaping (Result, Result) -> Bool, _ tree: I<IBinaryTree<Element>>, empty: Result, combine: @escaping (Element, Result, Result) -> Result) -> I<Result> {
    func helper(_ theTree: I<IBinaryTree<Element>>, _ destination: I<Result>) {
    theTree.read { switch $0 {
    case .empty:
        destination.write(empty)
    case .node(let value, left: let l, right: let r):
        let resultL = I<Result>(isEqual: isEqual)
        helper(l, resultL)
        let resultR = I<Result>(isEqual: isEqual)
        helper(r, resultR)
        resultL.read { l in
            resultR.read { r in
                destination.write(combine(value, l, r))
            }
        }
    }}
    }
    let destination = I<Result>(isEqual: isEqual)
    helper(tree, destination)
    return destination
}

func unsafeInsert<Element>(_ tree: I<IBinaryTree<Element>>, _ newElement: Element) {
    switch tree.value! {
    case .empty:
        tree.write(constant: .node(newElement, left: I(value: .empty), right: I(value: .empty)))
    case let .node(element, left: l, right: r):
        if newElement < element {
            unsafeInsert(l, newElement)
        } else {
            unsafeInsert(r, newElement)
        }
    }
}
