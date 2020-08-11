//
//  PeopleViewController.swift
//  People
//
//  Created by Ethan Nagel on 8/7/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine

import RealmSwift

class PeopleViewController: UITableViewController {
    typealias VM = PeopleViewModel
    
    var bindings = Set<AnyCancellable>()
    lazy var viewModel = PeopleViewModel()
    
    func bind() {
        
        viewModel.title.sink { (title) in
            self.title = title
        }.store(in: &bindings)
        
        viewModel.items.changeSetPublisher.sink { [weak self] (changes) in
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
        }.store(in: &bindings)
        
        self.tableView.reloadData()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }
}

extension PeopleViewController {
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return viewModel.items.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: PeopleViewControllerCell.self), for: indexPath) as! PeopleViewControllerCell
        
        cell.bind(to: viewModel.items[indexPath.row])
        
        return cell
    }
}

extension PeopleViewController {
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        let item = self.viewModel.items[indexPath.row]
        
        let viewController = PersonViewController.instantiate(personId: item.id)
        
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

class PeopleViewControllerCell: UITableViewCell {
    var bindings = Set<AnyCancellable>()
    var id: String?
    
    override func prepareForReuse() {
        bindings.removeAll()
        id = nil
        super.prepareForReuse()
    }
    
    func bind(to item: PeopleViewModel.Item) {
        id = item.id
        self.textLabel?.text = item.name
    }
}
