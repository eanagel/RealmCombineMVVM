//
//  PersonApi.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine

class PersonApi {
    struct AddPersonRequest: Codable {
        let id: String
        let firstName: String
        let lastName: String
        let phone: String
        let email: String
        let gender: Int
    }
    
    struct AddPersonResponse: Codable {
        let id: String
        let firstName: String
        let lastName: String
        let phone: String
        let email: String
        let gender: Int
    }
    
    init() {
    }
    
    func addPerson(_ request: AddPersonRequest) -> AnyPublisher<AddPersonResponse, Error> {
        // wait a bit then send our response. note the "server" returns a new ID and updates the case of the request on response...
        return Future { (promise) in
            MutationManager.queue.asyncAfter(deadline: .now() + .seconds(3)) {
                promise(.success(AddPersonResponse(id: request.id, firstName: request.firstName.capitalized, lastName: request.lastName.capitalized, phone: request.phone, email: request.email.lowercased(), gender: request.gender)))
            }
        }
        .eraseToAnyPublisher()
    }
}
