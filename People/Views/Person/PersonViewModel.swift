//
//  PersonViewModel.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

class PersonViewModel {
    public let fullName: AnyPublisher<String, Never>

    public let firstName: AnyPublisher<String, Never>
    public let lastName: AnyPublisher<String, Never>

    init(personId: String) {
        let realm = try! Realm()
        
        guard let person = realm.object(ofType: Person.self, forPrimaryKey: personId) else {
            fatalError() // hmmm
        }
        
        firstName = person.propertyValuePublisher(\.firstName)
        lastName = person.propertyValuePublisher(\.lastName)
        
        // getting the fullname requires combining the latest values
        
        fullName = Publishers.CombineLatest(firstName, lastName).map({ "\($0.0) \($0.1)" }).eraseToAnyPublisher()
    }
}
