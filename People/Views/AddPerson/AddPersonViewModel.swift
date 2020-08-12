//
//  AddPersonViewModel.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine


class AddPersonViewModel {
    let firstName = CurrentValueSubject<String, Never>("")
    let lastName = CurrentValueSubject<String, Never>("")
    
    lazy var canAddPerson = Publishers.CombineLatest(self.firstName, self.lastName).map({ !$0.0.isEmpty && !$0.1.isEmpty }).eraseToAnyPublisher()
    
    init() {
    }
    
    func addPerson() {
        Person.add(firstName: self.firstName.value, lastName: self.lastName.value, phone: "", email: "")
    }
}
