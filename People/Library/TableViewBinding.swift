//
//  TableViewBinding.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine

func *=<Element: BindableViewModelItem>(_ lhs: UITableView, _ rhs: ViewModelItemArray<Element>) where Element.View: UITableViewCell {
    let dataSource = TableViewBinding(tableView: lhs, items: rhs)
    lhs.dataSource = dataSource
    BindingGroup.add(dataSource)
}

class TableViewBinding<Element: BindableViewModelItem>: NSObject, UITableViewDataSource, Cancellable where Element.View: UITableViewCell {
    let tableView: UITableView
    let items: ViewModelItemArray<Element>
    private var binding: AnyCancellable?
    
    typealias Cell = Element.View
    
    init(tableView: UITableView, items: ViewModelItemArray<Element>) {
        self.tableView = tableView
        self.items = items
        
        super.init()
        
        self.binding = items.changeSetPublisher.sink { [weak self] (changes) in
            guard let self = self else { return }
            
            // apply changes...
            
            switch(changes) {
            case .initial:
                self.tableView.reloadData()
            case .update(_, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                self.tableView.performBatchUpdates({
                    self.tableView.insertRows(at: insertions.map({ IndexPath(item: $0, section: 0) }), with: .automatic)
                    self.tableView.deleteRows(at: deletions.map({ IndexPath(item: $0, section: 0) }), with: .automatic)
                    self.tableView.reloadRows(at: modifications.map({ IndexPath(item: $0, section: 0) }), with: .automatic)
                }, completion: nil)
                
            case .error:
                break
            }
        }
    }
    
    deinit {
        cancel()
    }
    
    func cancel() {
        binding?.cancel()
        binding = nil
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: Cell.self), for: indexPath) as! Cell
        
        cell.bind(to: self.items[indexPath.row])
        
        return cell
    }

}
