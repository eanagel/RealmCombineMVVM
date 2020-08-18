//
//  ViewModel.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

public protocol ViewModelItem {
    associatedtype Model: Object
    
    init(_ model: Model)
}

/// Stateful ViewModelItems maintain their state and shouldn't be overwritten when updates are observed
/// in the underlying model. Use this when you are using data binding between your Model and your
/// ViewModelItem.
public protocol StatefulViewModelItem: AnyObject, ViewModelItem {
}

protocol ObjectPropertyValuePublisher {
}

extension ObjectPropertyValuePublisher {
    /// Observes a single property on a realm object
    func propertyValuePublisher<T>(_ keyPath: KeyPath<Self, T>) -> AnyPublisher<T, Never> where Self: Object  {
        return Combine.Publishers.Merge(Just(self[keyPath: keyPath]), self.objectWillChange.map({ self[keyPath: keyPath] })).eraseToAnyPublisher()
    }
}

extension Object: ObjectPropertyValuePublisher { }
