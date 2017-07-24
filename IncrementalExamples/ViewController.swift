//
//  ViewController.swift
//  IncrementalExamples
//
//  Created by Chris Eidhof on 23.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit

class ViewController: UITableViewController {
    var inc = Incremental()
    var backing: [String] = []
    var change: ((ArrayChange<String>) -> ())!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        backing = ["One", "Two", "Three", "Four"]
        let (arr, change) = inc.array(initial: backing)
        self.change = change
        var processed: Int = 0
        let filtered: IArray<String> = inc.filter(array: arr, condition: { $0.characters.count > 3 })
        let signal: I<([String], [ArrayChange<String>])> = self.inc.reduce(isEqual: { $0.0 == $1.0 && $0.1 == $1.1 }, filtered.changes, (filtered.initial, []), { acc, change in
            return (acc.0.applying(change: change), acc.1 + [change])
        })
        signal.read { (c, changes) in
            self.backing = c
            let newProcessed = changes.count
            self.tableView.beginUpdates()
            for c in changes.dropFirst(processed) {
                self.animate(c)
                print(c)
            }
            self.tableView.endUpdates()
            processed = newProcessed
        }
    }
    
    func animate(_ change: ArrayChange<String>) {
        func ip(_ int: Int) -> IndexPath { return IndexPath(row: int, section: 0)}
        switch change {
        case .append(_):
            let newIndexPath = ip(backing.count-1)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        case let .insert(_, at: i):
            tableView.insertRows(at: [ip(i)], with: .automatic)
        default:
            fatalError()
        }
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return backing.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell")!
        cell.textLabel?.text = backing[indexPath.row]
        return cell
    }

    @IBAction func add(_ sender: Any) {
        change(.insert(element: "Hi", at: Int(arc4random()) % (backing.count)))
        change(.append("A Number"))
        inc.propagate()
    }
}

