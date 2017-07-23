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
        let iArray = inc.array(initial: backing)
        change = iArray.change
        let signal: I<[String]> = self.inc.reduce(isEqual: ==, iArray.changes, self.backing, { b, change in
            let new = b.applying(change: change)
            self.backing = new
            self.animate(change)
            return new
        })
        signal.read { c in
            self.backing = c
        }
    }
    
    func animate(_ change: ArrayChange<String>) {
        switch change {
        case .append(_):
            let newIndexPath = IndexPath(row: backing.count-1, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
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
        change(.append("A Number"))
        inc.propagate()
    }
}

