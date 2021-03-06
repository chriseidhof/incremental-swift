//
//  ViewController.swift
//  IncrementalExamples
//
//  Created by Chris Eidhof on 23.07.17.
//  Copyright © 2017 objc.io. All rights reserved.
//

import UIKit
import Incremental_iOS

class ViewController: UITableViewController {
    var backing: [String] = []
    var change: ((ArrayChange<String>) -> ())!
    var observer: Any? = nil
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "Cell")
        let (arr, change) = Incremental.shared.array(initial: ["One", "Two", "Three", "Four"])
        self.change = change
        var pendingChanges: [ArrayChange<String>] = []
        
        let filtered: IArray<String> = Incremental.shared.filter(array: arr, condition: { $0.characters.count > 3 })
        let sorted = Incremental.shared.sort(array: filtered, { $0.compare($1) })
        backing = sorted.initial
        let signal: I<()> = Incremental.shared.reduce(isEqual: { _, _ in false }, sorted.changes, (), { _, change in
            self.backing.apply(change: change)
            pendingChanges.append(change)
        })
        observer = signal.observe {
            self.tableView.beginUpdates()
            for c in pendingChanges {
                self.animate(c)
                print(c)
            }
            pendingChanges = []
            self.tableView.endUpdates()
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
        Incremental.shared.propagate()
    }
    
    @IBAction func showStackView(_ sender: Any) {        navigationController?.pushViewController(UIViewController(), animated: true)
    }
}

