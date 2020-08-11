//
//  Person.swift
//  People
//
//  Created by Ethan Nagel on 8/7/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import RealmSwift

class Person: Object {
    @objc dynamic var id = UUID().uuidString
    @objc dynamic var firstName = ""
    @objc dynamic var lastName = ""
    @objc dynamic var phone = ""
    @objc dynamic var email = ""
    
    override class func primaryKey() -> String? { "id" }
    override class func indexedProperties() -> [String] { ["firstName", "lastName"] }
}
