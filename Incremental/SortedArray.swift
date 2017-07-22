import Foundation

public struct SortedArray<Element: Comparable> {
    public var elements: [Element]
    
    public init() {
        self.elements = []
    }
    
    public init<S: Sequence>(unsorted: S) where S.Iterator.Element == Element {
        elements = unsorted.sorted()
    }
    
    func index(for element: Element) -> Int {
        var start = elements.startIndex
        var end = elements.endIndex
        while start < end {
            let middle = start + (end - start) / 2
            if elements[middle] < element {
                start = middle + 1
            } else {
                end = middle
            }
        }
        assert(start == end)
        return start
    }
    
    @discardableResult
    public mutating func insert(_ element: Element) -> Int {
        let newIndex = index(for: element)
        elements.insert(element, at: newIndex)
        return newIndex
    }
    
    mutating func insert<S: Sequence>(contentsOf s: S) where S.Iterator.Element == Element {
        // todo this can be implemented more efficiently
        for e in s {
            insert(e)
        }
    }
    
    
    public mutating func remove(at index: Int) -> Element {
        return elements.remove(at: index)
    }
    
    public func index(of element: Element) -> Int? {
        let index = self.index(for: element)
        guard index < elements.endIndex, elements[index] == element else { return nil }
        return index
    }
    
    mutating func remove(where cond: (Element) -> Bool) {
        for i in (0..<elements.endIndex).reversed() {
            if cond(elements[i]) {
                elements.remove(at: i)
            }
        }
    }
}

extension SortedArray: Collection {
    public var startIndex: Int {
        return elements.startIndex
    }
    
    public var endIndex: Int {
        return elements.endIndex
    }
    
    public subscript(index: Int) -> Element {
        return elements[index]
    }
    
    public func index(after i: Int) -> Int {
        return elements.index(after: i)
    }
}

