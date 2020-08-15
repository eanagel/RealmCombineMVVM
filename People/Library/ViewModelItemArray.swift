//
//  ViewModelItemArray.swift
//  People
//
//  Created by Ethan Nagel on 8/14/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

extension Publisher {
    public func mapRealmCollectionChanges<Source, Target, OutputType: RandomAccessCollection>(_ mapElement: @escaping (Source) -> Target, applyModifications: Bool = true) -> AnyPublisher<RealmCollectionChange<[Target]>, Failure> where Output == RealmCollectionChange<OutputType>, OutputType.Element == Source, OutputType.Index == Int {
        
        // something like this should allow us to update the array without mapping the results each time...
        // this will be required to support applyModifications == false
        
//        return self.reduce(RealmCollectionChange<[Target]>.initial([])) { (last, source) in
//            var items: [Target] = {
//                switch(last) {
//                case .initial(let items):
//                    return items
//                case .update(let items, deletions: _, insertions: _, modifications: _):
//                    return items
//                case .error:
//                    return []
//                }
//            }()
//
//            switch(source) {
//            case .initial(let sourceItems):
//                Swift.print("mapChanges: mapping initial items")
//                items = Array(sourceItems.map(mapElement))
//                return .initial(items)
//
//            case .update(let sourceItems, deletions: let deletions, insertions: let insertions, modifications: let modifications):
//                // apply changes to our items...
//
//                Swift.print("mapChanges: mapping deletions: \(deletions), insertions: \(insertions), modifications: \(modifications)")
//
//                for index in deletions.sorted().reversed() {
//                    items.remove(at: index)
//                }
//
//                for index in insertions.sorted() {
//                    items.insert(mapElement(sourceItems[index]), at: index)
//                }
//
//                if (applyModifications) {
//                    for index in modifications.sorted() {
//                        items[index] = mapElement(sourceItems[index])
//                    }
//                }
//
//                return .update(items, deletions: deletions, insertions: insertions, modifications: (applyModifications) ? modifications : [])
//
//            case .error(let e):
//                Swift.print("mapChanges: mapping error \(e)")
//                return .error(e)
//            }
//        }.eraseToAnyPublisher()

        guard applyModifications == true else {
            fatalError("applyModifications == false is not currently supported.")
        }
        
        return self.map { (source) -> RealmCollectionChange<[Target]> in
            switch(source) {
            case .initial(let sourceItems):
                Swift.print("mapChanges: mapping initial items")
                return .initial(Array(sourceItems.map(mapElement)))
                
            case .update(let sourceItems, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                // apply changes to our items...
                
                Swift.print("mapChanges: mapping deletions: \(deletions), insertions: \(insertions), modifications: \(modifications)")
                
                return .update(Array(sourceItems.map(mapElement)), deletions: deletions, insertions: insertions, modifications: (applyModifications) ? modifications : [])
                
            case .error(let e):
                Swift.print("mapChanges: mapping error \(e)")
                return .error(e)
            }
        }.eraseToAnyPublisher()
    }
    
    public func currentValuePublisher<Element, OutputType:RandomAccessCollection>() -> AnyPublisher<[Element], Failure> where Output == RealmCollectionChange<OutputType>, OutputType.Element == Element {
        return self.map { (changes) -> [Element] in
            switch(changes) {
            case .initial(let items):
                return Array(items)
            case .update(let items, deletions: _, insertions: _, modifications: _):
                return Array(items)
            case .error:
                return []
            }
        }.eraseToAnyPublisher()
    }
}

/// Transforms a Realm collection of Models into an array of view model items. Changes to items are tracked. Items may be subscribed to via Combine
/// you may subscrive to this publisher to get changes to the array of transofmred items. You may subscribe to `changeSetPublisher` to receive
/// changes as they happen (inserts, updates and deletes.)
public class ViewModelItemArray<Element>  {
    private var token: NotificationToken?
    
    private var createChangeSetPublisher: (() -> AnyPublisher<RealmCollectionChange<[Element]>, Never>)!
    
    /// subscribe to this publisher to get notified whenever this list changes, including the inserts, updates and deletes that were made.
    public lazy var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> = self.createChangeSetPublisher()
    public lazy var currentValuePublisher: AnyPublisher<[Element], Never> = self.changeSetPublisher.currentValuePublisher()

    /// The current mapped items. Changes made to the underlying models will appear here.
    public private(set) var items: [Element] = []
    
    /// creates a new ViewModelItemArray and subscribes to changes.
    /// - Parameters:
    ///   - query: the realm query to subscribe to
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    ///   - mapBlock: block that maps the Model into the Element.
    public init<M: RealmCollectionValue>(_ query: Results<M>, preload: Bool, applyUpdates: Bool, mapBlock: @escaping (M) -> Element) {
        func basePublisher() -> AnyPublisher<RealmCollectionChange<[Element]>, Never> {
            query
                .changesetPublisher
                .mapRealmCollectionChanges(mapBlock, applyModifications: applyUpdates)
                .map({ [weak self] (changes) in // capture the latest version of items in the items array
                    switch(changes) {
                    case .initial(let items):
                        self?.items = items
                    case .update(let items, deletions: _, insertions: _, modifications: _):
                        self?.items = items
                    case .error:
                        break
                    }
                    
                    return changes
                })
                .eraseToAnyPublisher()
        }
        
        if preload {
            // this will perform the query synchronously...
            
            let items = Array(query.map(mapBlock))
            
            self.createChangeSetPublisher = {
                return Just(RealmCollectionChange.initial(items)).append(basePublisher()).eraseToAnyPublisher()
            }
            
        } else {
            self.createChangeSetPublisher = basePublisher
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

