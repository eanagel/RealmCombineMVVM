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


/// Transforms a Realm collection of Models into an array of view model items. Changes to items are tracked. Items may be subscribed to via Combine
/// you may subscrive to this publisher to get changes to the array of transofmred items. You may subscribe to `changeSetPublisher` to receive
/// changes as they happen (inserts, updates and deletes.)
public class ViewModelItemArray<Element>: Publisher  {
    public typealias Output = [Element]
    public typealias Failure = Never
    
    private var token: NotificationToken?
    
    /// The current iew model items. Changes made to the underlying models will appear here.
    public private(set) var items: [Element]
    
    /// subscribe to this publisher to get notified whenever this list changes, including the inserts, updates and deletes that were made.
    public let changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never>
    
    public func receive<S>(subscriber: S) where S : Subscriber, S.Failure == Never, S.Input == [Element] {
        // current value publisher...
        
        changeSetPublisher.map({ (change) -> [Element] in
            switch(change) {
            case .initial(let items): return items
            case .update(let items, deletions: _, insertions: _, modifications: _): return items
            case .error: return []
            }
            }).receive(subscriber: subscriber)
    }

    
    /// creates a new ViewModelItemArray and subscribes to changes.
    /// - Parameters:
    ///   - query: the realm query to subscribe to
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    ///   - mapBlock: block that maps the Model into the Element.
    public init<M: RealmCollectionValue>(_ query: Results<M>, preload: Bool, applyUpdates: Bool, mapBlock: @escaping (M) -> Element) {
        self.items = (preload) ? Array(query.map(mapBlock)) : []
        
        let subject = PassthroughSubject<RealmCollectionChange<[Element]>, Never>()
        self.changeSetPublisher = subject.share().eraseToAnyPublisher()
        
        self.token = query.observe { [weak self] (change) in
            guard let self = self else { return }
            
            let mappedChange: RealmCollectionChange<[Element]> = {
                switch(change) {
                case .initial(let models):
                    if !preload {
                        self.items = Array(models.map(mapBlock))
                    }
                    return .initial(self.items)
                    
                case .update(let models, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    // apply changes to our items...
                    
                    for index in deletions.sorted().reversed() {
                        self.items.remove(at: index)
                    }
                    
                    for index in insertions.sorted() {
                        self.items.insert(mapBlock(models[index]), at: index)
                    }
                    
                    if (applyUpdates) {
                        for index in modifications.sorted() {
                            self.items[index] = mapBlock(models[index])
                        }
                    }
                    
                    return .update(self.items, deletions: deletions, insertions: insertions, modifications: modifications)
                    
                case .error(let e):
                    return .error(e)
                }
            }()
            
            subject.send(mappedChange)
        }
    }
}

extension ViewModelItemArray: RandomAccessCollection {
    public typealias Index = Int

    public subscript(position: Int) -> Element { items[position] }

    public var startIndex: Int { items.startIndex }

    public var endIndex: Int { items.endIndex }

    public var count: Int { items.count }
}

extension ViewModelItemArray where Element: ViewModelItem {
    /// creates a new ViewModelItemArray and subscribes to changes.
    /// - Parameters:
    ///   - query: the realm query to subscribe to
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    convenience init(_ query: Results<Element.Model>, preload: Bool, applyUpdates: Bool)  {
        self.init(query, preload: preload, applyUpdates: applyUpdates, mapBlock: { Element($0) })
    }
}

extension Results {
    
    /// creates a new ViewModelItemArray and subscribes to changes.
    /// - Parameters:
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    ///   - mapBlock: block that maps the Model into the Element.
    func asItemArray<T>(preload: Bool = false, applyUpdates: Bool = true, mapBlock: @escaping (Results.Element) -> T) -> ViewModelItemArray<T> {
        return ViewModelItemArray(self, preload: preload, applyUpdates: applyUpdates, mapBlock: mapBlock)
    }

    /// creates a new ViewModelItemArray and subscribes to changes.
    /// - Parameters:
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    func asItemArray<T: ViewModelItem>(preload: Bool = false, applyUpdates: Bool = true) -> ViewModelItemArray<T> where T.Model == Results.Element {
        return ViewModelItemArray(self, preload: preload, applyUpdates: applyUpdates)
    }
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
