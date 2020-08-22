//
//  AddPersonMutation.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

class AddPersonMutation: Mutation {
    let localId: String
    let firstName: String
    let lastName: String
    let phone: String
    let email: String
    let gender: Gender
        
    init(firstName: String, lastName: String, phone: String, email: String, gender: Gender) {
        self.firstName = firstName
        self.lastName = lastName
        self.phone = phone
        self.email = email
        self.gender = gender
        self.localId =  UUID().uuidString
    }

    func start() throws {
        print("AddPersonMutation starting")
        let realm = try Realm()
        try realm.write {
            let person = Person()
            person.id = self.localId
            person.firstName = self.firstName
            person.lastName = self.lastName
            person.phone = self.phone
            person.email = self.email
            person.gender = self.gender
        
            realm.add(person)
        }
    }
    
    func rollback() throws {
        print("AddPersonMutation rolling back")
        let realm = try Realm()
        
        try realm.write {
            if let person = realm.object(ofType: Person.self, forPrimaryKey: self.localId) {
                realm.delete(person)
            }
        }
    }
    
    func performMutation() throws {
        print("AddPersonMutation performMutation")
        
        let api = PersonApi()
                
        let call = api.addPerson(.init(id: localId, firstName: firstName, lastName: lastName, phone: phone, email: email, gender: gender.rawValue))
            .tryMap({ (response) -> Person in
                let realm = try Realm()
            
                return try realm.write {
                    guard let person = realm.object(ofType: Person.self, forPrimaryKey: self.localId) else {
                        throw "Person not found"
                    }
                    
                    person.firstName = response.firstName
                    person.lastName = response.lastName
                    person.phone = response.phone
                    person.email = response.email
                    person.gender = Gender(rawValue: response.gender) ?? .undisclosed
                    
                    return person
                }
            }).threadSafeReference()
            
        var sink: AnyCancellable? = nil
        
        sink = call.sink(receiveCompletion: { (completion) in
            if case let .failure(error) = completion {
                self.fail(error)
            }
            if sink != nil {
                sink = nil // break retain cycle
            }
        }) { (person) in
            print("AddPersonMutation succeeded")
        }
    }
}
