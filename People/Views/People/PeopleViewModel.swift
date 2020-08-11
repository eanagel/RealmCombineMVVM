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
    let items: ViewModelItemArray<Item>
    
    var bindings = Set<AnyCancellable>()
    
    init() {
        let realm = try! Realm()

        self.items = realm.objects(Person.self)
            .sorted(by: ["firstName", "lastName"])
            .asItemArray()
        
        self.title = self.items.map({ "People (\($0.count))" }).eraseToAnyPublisher()
    }
}

extension PeopleViewModel {
    class Item: ViewModelItem {
        let id: String
        let name: String
        
        required init(_ person: Person) {
            id = person.id
            name = "\(person.firstName) \(person.lastName)"
        }
    }
}
