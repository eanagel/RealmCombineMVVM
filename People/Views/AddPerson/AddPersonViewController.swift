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




class GenderDataSourceBase: PickerViewComponentBinding {
    var items: [Gender] = [] {
        didSet {
            self.pickerView?.reloadComponent(0)
        }
    }
    
    override func numberOfComponents(in pickerView: UIPickerView) -> Int {
        1
    }
    
    override func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return items.count
    }
    
}

class GenderDataSource: GenderDataSourceBase {
    private class StringItems: GenderDataSource {
//    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
//        return items[row].name
//    }
        func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            return "Row \(row)"
        }
    }
    
    public static func items() -> GenderDataSource {
        return StringItems.init()
    }
}

class AddPersonViewController: UIViewController {
    @IBOutlet weak var firstNameTextField: UITextField!
    @IBOutlet weak var lastNameTextField: UITextField!
    @IBOutlet weak var genderTextField: UITextField!
    @IBOutlet var genderToolbar: UIToolbar!
    @IBOutlet var genderPickerView: UIPickerView!
    @IBOutlet weak var addPersonButton: UIButton!
    
    private var viewModel: AddPersonViewModel!
    private var bindings: BindingGroup?
    
    func bind() {
        bindings = BindingGroup {
            addPersonButton.isEnabledBinding *= viewModel.canAddPerson
            self.firstNameTextField *= TextFieldBinding.subject(viewModel.firstName).nextField(self.lastNameTextField)
            self.lastNameTextField *= TextFieldBinding.subject(viewModel.lastName).nextField(self.genderTextField)
            self.genderTextField.textBinding *= viewModel.gender.map(\.name)
            
            self.genderPickerView *= PickerViewComponentBinding.items(viewModel.genders).value(viewModel.gender)
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        genderTextField.inputView = genderPickerView
        genderTextField.inputAccessoryView = genderToolbar
        
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

    @IBAction func genderDoneEditing(_ sender: Any) {
        genderTextField.resignFirstResponder()
    }
    
    @IBAction func addPersonAction(_ sender: Any) {
        viewModel.addPerson()
        self.navigationController?.popViewController(animated: true)
    }
}

extension Gender: PickerViewElement {
    var pickerTitle: String? { self.name }
}
