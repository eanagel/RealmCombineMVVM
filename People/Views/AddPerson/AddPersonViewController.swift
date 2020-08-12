//
//  AddPersonViewController.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine

class AddPersonViewController: UIViewController {
    @IBOutlet weak var firstNameLabel: UITextField!
    @IBOutlet weak var lastNameLabel: UITextField!
    @IBOutlet weak var addPersonButton: UIButton!
    
    private var viewModel: AddPersonViewModel!
    private var bindings: BindingGroup?
    
    func bind() {
        bindings = BindingGroup {
            addPersonButton.isEnabledBinding *= viewModel.canAddPerson
            self.firstNameLabel *= TextFieldBinding.subject(viewModel.firstName).nextField(self.lastNameLabel)
            self.lastNameLabel *= TextFieldBinding.subject(viewModel.lastName)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        viewModel = AddPersonViewModel()
        bind()
    }
    
    static func instantiate() -> AddPersonViewController {
        let storyboard = UIStoryboard(name: "AddPerson", bundle: nil)
    
        guard let viewController = storyboard.instantiateInitialViewController() as? AddPersonViewController else {
            fatalError()
        }
        
        return viewController
    }

    @IBAction func addPersonAction(_ sender: Any) {
        viewModel.addPerson()
        self.navigationController?.popViewController(animated: true)
    }
}
