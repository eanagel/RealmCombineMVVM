//
//  ObservableArray.swift
//  People
//
//  Created by Ethan Nagel on 8/14/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import RealmSwift

extension RealmCollectionChange {
    public var value: CollectionType?  {
        switch self {
        case .initial(let value):
            return value
        case .update(let value, deletions: _, insertions: _, modifications: _):
            return value
        case .error:
            return nil
        }
    }
}

extension CollectionDifference.Change {
    public var offset: Int {
        switch self {
        case .insert(offset: let offset, element: _, associatedWith: _):
            return offset
        case .remove(offset: let offset, element: _, associatedWith: _):
            return offset
        }
    }
    
    public var element: ChangeElement {
        switch self {
        case .insert(offset: _, element: let element, associatedWith: _):
            return element
        case .remove(offset: _, element: let element, associatedWith: _):
            return element
        }
    }
}

extension Publisher {
    public func mapRealmCollectionChanges<Source, Target, OutputType: RandomAccessCollection>(_ mapElement: @escaping (Source) -> Target, applyModifications: Bool = true) -> AnyPublisher<RealmCollectionChange<[Target]>, Failure> where Output == RealmCollectionChange<OutputType>, OutputType.Element == Source, OutputType.Index == Int {
        return self.scan(.initial([])) { (lastChange, newChange) in
            switch(newChange) {
            case .initial(let newItems):
                return .initial(newItems.map(mapElement))
                
            case .update(let newItems, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                // apply the changes to the previous items, so we only actually map items that are inserted or modified...

                var items = lastChange.value!

                for index in deletions.sorted().reversed() {
                    items.remove(at: index)
                }
                
                for index in insertions.sorted() {
                    items.insert(mapElement(newItems[index]), at: index)
                }
                
                if applyModifications {
                    for index in modifications.sorted() {
                        items[index] = mapElement(newItems[index])
                    }
                }
                
                return .update(items, deletions: deletions, insertions: insertions, modifications: modifications)
                
            case .error(let error):
                return .error(error)
            }
        }.eraseToAnyPublisher()
    }
    
    public func currentValuePublisher<Element, OutputType:RandomAccessCollection>() -> AnyPublisher<[Element], Failure> where Output == RealmCollectionChange<OutputType>, OutputType.Element == Element {
        return self.map({ $0.value.map({ Array($0) }) ?? [] }).eraseToAnyPublisher()
    }
    
    public func diff<Element: Equatable>(initial: [Element] = []) -> AnyPublisher<RealmCollectionChange<[Element]>, Never> where Output == [Element], Failure == Never {
        return self.scan(RealmCollectionChange<[Element]>.initial(initial)) { (lastChange, newItems) in
            let lastItems = lastChange.value!
            
            let diff = newItems.difference(from: lastItems)
            
            return RealmCollectionChange.update(newItems, deletions: diff.removals.map({ $0.offset }), insertions: diff.insertions.map({ $0.offset }), modifications: [])
        }.eraseToAnyPublisher()
    }
    
    public func diff<Element: Identifiable>(initial: [Element] = []) -> AnyPublisher<RealmCollectionChange<[Element]>, Never> where Output == [Element], Failure == Never {
        return self.scan(RealmCollectionChange<[Element]>.initial(initial)) { (lastChange, newItems) in
            let lastItems = lastChange.value!
            
            let diff = newItems.difference(from: lastItems) { (a, b) -> Bool in
                return a.id == b.id
            }
            
            return RealmCollectionChange.update(newItems, deletions: diff.removals.map({ $0.offset }), insertions: diff.insertions.map({ $0.offset }), modifications: [])
        }.eraseToAnyPublisher()
    }
    
    public func diff<Element: Identifiable & Equatable>(initial: [Element] = [], trackModifications: Bool) -> AnyPublisher<RealmCollectionChange<[Element]>, Never> where Output == [Element], Failure == Never {
        return self.scan(RealmCollectionChange<[Element]>.initial(initial)) { (lastChange, newItems) in
            let lastItems = lastChange.value!
            
            let diff = newItems.difference(from: lastItems) { (a, b) -> Bool in
                return a.id == b.id
            }
            
            let modifications = (trackModifications)
                ? Swift.zip(lastItems.applying(diff)!, newItems)
                    .enumerated()
                    .compactMap({ $1.0 == $1.1 ? $0 : nil })
                : []
            
            return RealmCollectionChange.update(newItems, deletions: diff.removals.map({ $0.offset }), insertions: diff.insertions.map({ $0.offset }), modifications: modifications)
        }.eraseToAnyPublisher()
    }
}

/// An array of Elements with observable changes
public protocol ObservableArray {
    associatedtype Element
    
    var items: [Element] { get }
    
    /// subscribe to this publisher to get notified whenever this list changes, including the inserts, updates and deletes that were made.
    var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> { get }
}

extension ObservableArray {
    public var currentValuePublisher: AnyPublisher<[Element], Never> { self.changeSetPublisher.currentValuePublisher() }
}

extension ObservableArray { // RandomAccessCollection
    public subscript(position: Int) -> Element { items[position] }

    public var startIndex: Int { items.startIndex }

    public var endIndex: Int { items.endIndex }
}

/// Transforms a Realm collection of Models into an array of view model items. Changes to items are tracked. Items may be subscribed to via Combine
/// you may subscrive to this publisher to get changes to the array of transofmred items. You may subscribe to `changeSetPublisher` to receive
/// changes as they happen (inserts, updates and deletes.)
public class QueryObservableArray<Element>: ObservableArray, RandomAccessCollection {
    private var token: NotificationToken?
    
    private var createChangeSetPublisher: (() -> AnyPublisher<RealmCollectionChange<[Element]>, Never>)!
    
    public lazy var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> = self.createChangeSetPublisher()

    /// The current mapped items. Changes made to the underlying models will appear here.
    public private(set) var items: [Element] = []
    
    /// creates a new QueryObservableArray and subscribes to changes.
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

extension QueryObservableArray where Element: ViewModelItem {
    /// creates a new QuerylObservableArray and subscribes to changes.
    /// - Parameters:
    ///   - query: the realm query to subscribe to
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    convenience init(_ query: Results<Element.Model>, preload: Bool)  {
        self.init(query, preload: preload, applyUpdates: true, mapBlock: { Element($0) })
    }
}

extension QueryObservableArray where Element: StatefulViewModelItem {
    /// creates a new QuerylObservableArray and subscribes to changes.
    /// - Parameters:
    ///   - query: the realm query to subscribe to
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    convenience init(_ query: Results<Element.Model>, preload: Bool)  {
        self.init(query, preload: preload, applyUpdates: false, mapBlock: { Element($0) })
    }
}

public class MutableObservableArray<Element>: ObservableArray, RandomAccessCollection {
    private let createChangeSetPublisher: () -> AnyPublisher<RealmCollectionChange<[Element]>, Never>
    
    public lazy var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> = self.createChangeSetPublisher()

    private let _items: CurrentValueSubject<[Element], Never>
    public var items: [Element] {
        get { return _items.value }
        set { _items.value = newValue }
    }
    
    private init(items: CurrentValueSubject<[Element], Never>, createChangeSetPublisher: @escaping () -> AnyPublisher<RealmCollectionChange<[Element]>, Never>) {
        self._items = items
        self.createChangeSetPublisher = createChangeSetPublisher
    }
}

extension MutableObservableArray where Element: Equatable {
    public convenience init(_ initial: [Element]) {
        let items = CurrentValueSubject<[Element], Never>(initial)
        self.init(items: items, createChangeSetPublisher: { items.diff(initial: initial) })
    }
}

extension MutableObservableArray where Element: Identifiable {
    public convenience init(_ initial: [Element]) {
        let items = CurrentValueSubject<[Element], Never>(initial)
        self.init(items: items, createChangeSetPublisher: { items.diff(initial: initial) })
    }
}

extension MutableObservableArray where Element: Identifiable&Equatable {
    public convenience init(_ initial: [Element], trackModifications: Bool) {
        let items = CurrentValueSubject<[Element], Never>(initial)
        self.init(items: items, createChangeSetPublisher: { items.diff(initial: initial, trackModifications: trackModifications) })
    }
}

public class ImmutableObservableArray<Element>: ObservableArray, RandomAccessCollection {
    public lazy var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> = Just(RealmCollectionChange.initial(self.items)).eraseToAnyPublisher()
    public let items: [Element]
    
    public init(_ items: [Element]) {
        self.items = items
    }
}

public class AnyObservableArray<Element>: ObservableArray, RandomAccessCollection {
    private let getChangeSetPublisher: () -> AnyPublisher<RealmCollectionChange<[Element]>, Never>
    private let getItems: () -> [Element]
    
    public var changeSetPublisher: AnyPublisher<RealmCollectionChange<[Element]>, Never> { getChangeSetPublisher() }
    public var items: [Element] { getItems() }
    
    public init<Wrapped: ObservableArray>(_ wrapped: Wrapped) where Wrapped.Element == Element {
        self.getChangeSetPublisher = { wrapped.changeSetPublisher }
        self.getItems = { wrapped.items }
    }
}

extension ObservableArray {
    public func eraseToAnyObservableArray() -> AnyObservableArray<Element> {
        return AnyObservableArray(self)
    }
}

extension Results {
    /// creates a new QueryObservableArray and subscribes to changes.
    /// - Parameters:
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    ///   - mapBlock: block that maps the Model into the Element.
    public func asObservableArray<T>(preload: Bool = false, applyUpdates: Bool = true, mapBlock: @escaping (Results.Element) -> T) -> AnyObservableArray<T> {
        return QueryObservableArray(self, preload: preload, applyUpdates: applyUpdates, mapBlock: mapBlock).eraseToAnyObservableArray()
    }

    /// creates a new QueryObservableArray and subscribes to changes.
    /// - Parameters:
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    public func asObservableArray<T: ViewModelItem>(preload: Bool = false) -> AnyObservableArray<T> where T.Model == Results.Element {
        return QueryObservableArray(self, preload: preload).eraseToAnyObservableArray()
    }
    
    /// creates a new QueryObservableArray and subscribes to changes.
    /// - Parameters:
    ///   - preload: true if the results should be preloaded and immediately available. This will cause a syncronous query to Realm. If possible, leave preload as false.
    ///   - applyUpdates: true if any updated items should be replaced
    public func asObservableArray<T: StatefulViewModelItem>(preload: Bool = false) -> AnyObservableArray<T> where T.Model == Results.Element {
        return QueryObservableArray(self, preload: preload).eraseToAnyObservableArray()
    }
}

extension Array {
    public func asObservableArray() -> AnyObservableArray<Element> {
        return ImmutableObservableArray(self).eraseToAnyObservableArray()
    }
}

