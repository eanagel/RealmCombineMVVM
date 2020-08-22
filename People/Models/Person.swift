//
//  Person.swift
//  People
//
//  Created by Ethan Nagel on 8/7/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import RealmSwift

@objc enum Gender: Int, RealmEnum, Codable, CaseIterable {
    case undisclosed = 0
    case male = 1
    case female = 2
    
    var name: String {
        switch self {
        case .undisclosed: return "Undisclosed"
        case .male: return "Male"
        case .female: return "Female"
        }
    }
}

class Person: Object {
    @objc dynamic var id = UUID().uuidString
    @objc dynamic var firstName = ""
    @objc dynamic var lastName = ""
    @objc dynamic var phone = ""
    @objc dynamic var email = ""
    @objc dynamic var gender = Gender.undisclosed
    
    override class func primaryKey() -> String? { "id" }
    override class func indexedProperties() -> [String] { ["firstName", "lastName"] }
}

extension Person {
    @discardableResult static func add(firstName: String, lastName: String, phone: String, email: String, gender: Gender) -> AddPersonMutation {
        return MutationManager.shared.start(AddPersonMutation(firstName: firstName, lastName: lastName, phone: phone, email: email, gender: gender))
    }
}
