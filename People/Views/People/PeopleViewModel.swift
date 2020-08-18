//
//  PeopleViewModel.swift
//  People
//
//  Created by Ethan Nagel on 8/7/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

class PeopleViewModel {
    let title: AnyPublisher<String, Never>
    let items: AnyObservableArray<Item>
    
    init() {
        let realm = try! Realm()

        self.items = realm.objects(Person.self)
            .sorted(by: ["firstName", "lastName"])
            .asObservableArray()
        
        self.title = self.items.currentValuePublisher.map({ "People (\($0.count))" }).eraseToAnyPublisher()
    }
}

extension PeopleViewModel {
    struct Item: ViewModelItem { // This is an example of a stateless item
        let id: String
        let name: String
        
        init(_ person: Person) {
            id = person.id
            name = "\(person.firstName) \(person.lastName)"
        }
    }
}
