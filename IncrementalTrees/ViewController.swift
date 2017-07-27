//
//  ViewController.swift
//  IncrementalTrees
//
//  Created by Chris Eidhof on 26.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

extension BinaryTree {
    func inserting(_ newElement: Element) -> BinaryTree<Element> {
        switch self {
        case .empty:
            return .node(newElement, left: .empty, right: .empty)
        case let .node(element, left, right):
            if element < newElement {
                return .node(element, left: left.inserting(newElement), right: right)
            } else {
                return .node(element, left: left, right: right.inserting(newElement))
            }
        }
    }

    mutating func insert(_ newElement: Element) {
        self = inserting(newElement)
    }

    func contains(_ element: Element) -> Bool {
        switch self {
        case .empty:
            return false
        case let .node(member, left, right):
            if member == element {
                return true
            } else if member < element {
                return right.contains(element)
            }
            else {
                return left.contains(element)
            }
        }
    }
}




import UIKit

let nodeSize: CGFloat = 24.0
func renderNode(color: UIColor = .black, label: String) -> UIImage {
    let bounds = CGRect(x: 0, y: 0, width: nodeSize, height: nodeSize)
    let renderer = UIGraphicsImageRenderer(bounds: bounds)
    return renderer.image { context in
        let c = context.cgContext
        color.setFill()
        c.fillEllipse(in: bounds)
        let attributes: [NSAttributedStringKey: Any] = [
            .font: UIFont.boldSystemFont(ofSize: 12),
            .foregroundColor: UIColor.white
        ]
        let size = (label as NSString).size(withAttributes: attributes)
        let labelBounds = CGRect(origin: CGPoint(x: bounds.midX-size.width/2, y: bounds.midY-size.height/2), size: size)
        (label as NSString).draw(in: labelBounds, withAttributes: attributes)
    }
}
let horizontalPadding: CGFloat = 24
let verticalPadding: CGFloat = 20
struct TreeImage: Equatable {
    let image: UIImage
    let rootMidX: CGFloat
}

func ==(lhs: TreeImage, rhs: TreeImage) -> Bool {
    return lhs.rootMidX == rhs.rootMidX && lhs.image == rhs.image
}

func _render<Element>(tree: I<IBinaryTree<Element>>) -> I<TreeImage?> {
    func helper(_ tree: I<IBinaryTree<Element>>, _ dest: I<TreeImage?>) {
        tree.read { switch $0 {
        case .empty:
            dest.write(nil)
        case let .node(element, left: left, right: right):
            let nodeImage = renderNode(label: "\(element)")
            let lRec = I<TreeImage?>(isEqual: ==)
            helper(left, lRec)
            let rRec = I<TreeImage?>(isEqual: ==)
            helper(right, rRec)
            lRec.read { l in
                rRec.read { r in
                    switch (l, r) {
                    case (nil, nil):
                        dest.write(TreeImage(image: nodeImage, rootMidX: nodeSize / 2))
                    case let (leftImage, rightImage):
                        let leftSize = leftImage?.image.size ?? .zero
                        let rightSize = rightImage?.image.size ?? .zero
                        let bounds = CGRect(
                            x: 0,
                            y: 0,
                            width: leftSize.width + horizontalPadding + rightSize.width,
                            height: nodeImage.size.height + verticalPadding + Swift.max(leftSize.height, rightSize.height))
                        let nodeRect = CGRect(origin: CGPoint(x: leftSize.width + horizontalPadding / 2 - nodeImage.size.width / 2, y: 0),
                                              size: nodeImage.size)
                        let renderer = UIGraphicsImageRenderer(bounds: bounds)
                        let image = renderer.image { context in
                            let subtreeY = nodeImage.size.height + verticalPadding
                            let start = CGPoint(x: nodeRect.midX, y: nodeRect.midY)
                            if let leftImage = leftImage {
                                let leftRect = CGRect(origin: CGPoint(x: 0, y: subtreeY),
                                                      size: leftImage.image.size)
                                let end = CGPoint(x: leftImage.rootMidX, y: leftRect.minY + nodeSize / 2)
                                context.cgContext.drawLine(from: start, to: end)
                                leftImage.image.draw(at: leftRect.origin)
                            }
                            if let rightImage = rightImage {
                                let rightRect = CGRect(origin: CGPoint(x: nodeRect.midX + horizontalPadding / 2, y: subtreeY),
                                                       size: rightImage.image.size)
                                let end = CGPoint(x: rightRect.minX + rightImage.rootMidX, y: rightRect.minY + nodeSize / 2)
                                context.cgContext.drawLine(from: start, to: end)
                                rightImage.image.draw(at: rightRect.origin)
                            }
                            nodeImage.draw(at: nodeRect.origin)
                        }
                        dest.write(TreeImage(image: image, rootMidX: nodeRect.midX))
                    }
                }
            }
        }}
    }
    let result = I<TreeImage?>(isEqual: ==)
    helper(tree, result)
    return result
}

extension BinaryTree {
    func _render() -> TreeImage? {
        switch self {
        case .empty:
            return nil
        case let .node(element, left, right):
            let nodeImage = renderNode(label: "\(element)")
            switch (left._render(), right._render()) {
            case (nil, nil):
                return TreeImage(image: nodeImage, rootMidX: nodeSize / 2)
            case let (leftImage, rightImage):
                let leftSize = leftImage?.image.size ?? .zero
                let rightSize = rightImage?.image.size ?? .zero
                let bounds = CGRect(
                    x: 0,
                    y: 0,
                    width: leftSize.width + horizontalPadding + rightSize.width,
                    height: nodeImage.size.height + verticalPadding + Swift.max(leftSize.height, rightSize.height))
                let nodeRect = CGRect(origin: CGPoint(x: leftSize.width + horizontalPadding / 2 - nodeImage.size.width / 2, y: 0),
                                      size: nodeImage.size)
                let renderer = UIGraphicsImageRenderer(bounds: bounds)
                let image = renderer.image { context in
                    let subtreeY = nodeImage.size.height + verticalPadding
                    let start = CGPoint(x: nodeRect.midX, y: nodeRect.midY)
                    if let leftImage = leftImage {
                        let leftRect = CGRect(origin: CGPoint(x: 0, y: subtreeY),
                                              size: leftImage.image.size)
                        let end = CGPoint(x: leftImage.rootMidX, y: leftRect.minY + nodeSize / 2)
                        context.cgContext.drawLine(from: start, to: end)
                        leftImage.image.draw(at: leftRect.origin)
                    }
                    if let rightImage = rightImage {
                        let rightRect = CGRect(origin: CGPoint(x: nodeRect.midX + horizontalPadding / 2, y: subtreeY),
                                               size: rightImage.image.size)
                        let end = CGPoint(x: rightRect.minX + rightImage.rootMidX, y: rightRect.minY + nodeSize / 2)
                        context.cgContext.drawLine(from: start, to: end)
                        rightImage.image.draw(at: rightRect.origin)
                    }
                    nodeImage.draw(at: nodeRect.origin)
                }
                return TreeImage(image: image, rootMidX: nodeRect.midX)
            }
        }
    }

    func render() -> UIImage? {
        return _render()?.image
    }
}

extension CGContext {
    func drawLine(from start: CGPoint, to end: CGPoint, color: UIColor = .black, width: CGFloat = 1) {
        self.saveGState()
        self.move(to: start)
        self.addLine(to: end)
        UIColor.black.setStroke()
        self.setLineWidth(1)
        self.strokePath()
        self.restoreGState()
    }
}
extension Array {
    public mutating func shuffle() {
        for i in 0 ..< count {
            let j = Int(arc4random_uniform(UInt32(count)))
            if i != j {
                self.swapAt(i, j)
            }
        }
    }
}
extension Sequence {
    public func shuffled() -> [Iterator.Element] {
        var array = Array(self)
        array.shuffle()
        return array
    }
}

class ViewController1: UIViewController {

    @IBOutlet var imageView: UIImageView!

    @IBOutlet weak var add: UIBarButtonItem!

    var tree: I<IBinaryTree<Int>> = I(value: .empty)
    var observer: Any?

    @IBAction func add(_ sender: Any) {
        let time = DispatchTime.now()
        let new = Int(arc4random() % 100)
        unsafeInsert(tree, new)
        Incremental.shared.propagate()
        let diff = (DispatchTime.now().uptimeNanoseconds - time.uptimeNanoseconds) / 1_000_000
        print(diff)
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for _ in 0..<100 {
            unsafeInsert(tree, Int(arc4random() % 100))
        }

        observer = _render(tree: tree).observe { [unowned self] image in
            self.imageView.image = image?.image
        }

        //        let inOrder: I<[Int]> = reduceWith(isEqual: ==, tree, empty: [], combine: { x, l, r in
        //            l + [x] + r
        //        })
        //        observer = inOrder.observe { sum in
        //            print(sum)
        //        }

        //        var tree = BinaryTree<Int>.empty
        //        for x in (0..<10) {
        //            tree.insert(x)
        //        }
        //
        //        imageView.image = tree.render()

    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView!

    @IBOutlet weak var add: UIBarButtonItem!

    var tree: BinaryTree<Int> = .empty

    @IBAction func add(_ sender: Any) {
        let time = DispatchTime.now()
        let new = Int(arc4random() % 100)
        tree.insert(new)
        imageView.image = tree.render()
        let diff = (DispatchTime.now().uptimeNanoseconds - time.uptimeNanoseconds) / 1_000_000
        print(diff)

    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for _ in 0..<100 {
            tree.insert(Int(arc4random() % 100))
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}
