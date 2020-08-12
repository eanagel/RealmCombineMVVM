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
    
    var bindings: BindingGroup?
    lazy var viewModel = PeopleViewModel()
    
    func bind() {
        bindings = BindingGroup {
            self.titleBinding *= viewModel.title
            self.tableView *= self.viewModel.items
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        bind()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        self.tableView.deselectRow(at: indexPath, animated: true)
        
        let item = self.viewModel.items[indexPath.row]
        
        let viewController = PersonViewController.instantiate(personId: item.id)
        
        self.navigationController?.pushViewController(viewController, animated: true)
    }
    
    @IBAction func addPerson(_ sender: Any) {
        let viewController = AddPersonViewController.instantiate()
        
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension PeopleViewModel.Item: BindableViewModelItem {
    typealias View = PeopleViewControllerCell
}

class PeopleViewControllerCell: UITableViewCell, BindableView {
    var id: String?
    
    override func prepareForReuse() {
        id = nil
        super.prepareForReuse()
    }
    
    func bind(to item: PeopleViewModel.Item) {
        id = item.id
        self.textLabel?.text = item.name
    }
}
