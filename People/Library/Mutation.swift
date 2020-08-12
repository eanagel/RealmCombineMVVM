//
//  Mutation.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation

protocol Mutation: Codable {
    
    
    /// called when the mutation should start. Should make any local database changes
    func start() throws
    
    /// called to actually perform the mutation. This usually involves making an API call and then updating the database with any updated data from the
    /// server.
    func performMutation() throws
    
    /// called when the mutation has failed. by default this prints a message and calls rollback()
    func fail(_ error: Error)
    
    /// should undo the changes made in start(). Called as part of fail() or in scenarios where a mutation is being cancelled.
    func rollback() throws
}

extension Mutation {
    public func fail(_ error: Error) {
        print("Mutation Failed: \(error)")
        try? rollback() // try to roll back, but ignore errors
    }
}

class MutationManager {
    // The mutation manager doesn't really do much now, but in the future it can be responsible for
    // persisting mutations, handling offline scenarios and even handling dependencies between
    // mutations.
    
    public static let queue = DispatchQueue(label: "Mutation")
    public static let shared = MutationManager()
    
    @discardableResult public func start<M: Mutation>(_ mutation: M) -> M {
        Self.queue.async {
            do {
                try mutation.start()
                try mutation.performMutation()
            } catch {
                mutation.fail(error)
            }
        }
        
        return mutation
    }
}
