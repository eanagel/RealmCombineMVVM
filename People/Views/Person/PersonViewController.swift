//
//  PersonViewController.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine

class PersonViewController: UIViewController {
    @IBOutlet weak var firstName: UILabel!
    @IBOutlet weak var lastName: UILabel!
    
    var personId: String = ""
    private var viewModel: PersonViewModel!
    private var bindings: BindingGroup?
    
    func bind() {
        bindings = BindingGroup {
            self.titleBinding *= viewModel.fullName
            self.firstName.textBinding *= viewModel.firstName
            self.lastName.textBinding *= viewModel.lastName
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = PersonViewModel(personId: personId)
        bind()
    }
    
    static func instantiate(personId: String) -> PersonViewController {
        let storyboard = UIStoryboard(name: "Person", bundle: nil)
    
        guard let viewController = storyboard.instantiateInitialViewController() as? PersonViewController else {
            fatalError()
        }
        
        viewController.personId = personId
        
        return viewController
    }
}
