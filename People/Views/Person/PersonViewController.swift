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
    
    private var bindings = Set<AnyCancellable>()
    
    func bind() {
        viewModel.fullName.sink { (value) in
            self.title = value
        }.store(in: &bindings)
        
        viewModel.firstName.sink { (value) in
            self.firstName.text = value
        }.store(in: &bindings)
        
        viewModel.lastName.sink { (value) in
            self.lastName.text = value
        }.store(in: &bindings)
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
