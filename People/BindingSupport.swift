//
//  BindingSupport.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine

func *= <O, T, P>(lhs: Binding<O, T>, rhs: P) where P: Publisher, P.Output == T {
    BindingGroup.add(rhs.sink(lhs))
}

func *= <O, T, P>(lhs: Binding<O, T?>, rhs: P) where P: Publisher, P.Output == T {
    BindingGroup.add(rhs.sink(lhs))
}

class Binding<O: AnyObject, T> {
    let object: O
    let keyPath: WritableKeyPath<O, T>
    
    init(_ object: O, _ keyPath: WritableKeyPath<O, T>) {
        self.object = object
        self.keyPath = keyPath
    }
}

extension Publisher {
    func sink<O: AnyObject>(_ binding: Binding<O,Output>) -> AnyCancellable {
        let object = binding.object
        let keyPath = binding.keyPath
        
        var sink: AnyCancellable?
            
        sink = self.sink(receiveCompletion: { (_) in }) { [weak object, weak sink] (value) in
            guard var object = object else {
                sink?.cancel() // cancel the sink if the object no longer exists
                sink = nil
                return
            }
            
            object[keyPath: keyPath] = value
        }
        
        return sink!
    }
    
    func sink<O: AnyObject>(_ binding: Binding<O,Output?>) -> AnyCancellable {
        // todo: we shouldn't have to duplicate this!
        
        let object = binding.object
        let keyPath = binding.keyPath
        
        var sink: AnyCancellable?
            
        sink = self.sink(receiveCompletion: { (_) in }) { [weak object, weak sink] (value) in
            guard var object = object else {
                sink?.cancel() // cancel the sink if the object no longer exists
                sink = nil
                return
            }
            
            object[keyPath: keyPath] = value
        }
        
        return sink!
    }
}

class BindingGroup {
    private var items = Set<AnyCancellable>()
    
    static var current: BindingGroup? = nil
    
    func capture<T>(_ block: () -> T) -> T {
        let temp = BindingGroup.current
        BindingGroup.current = self
        
        let result = block()
        
        BindingGroup.current = temp
        
        return result
    }
    
    func add(_ binding: AnyCancellable) {
        items.insert(binding)
    }
    
    func clear() {
        items.removeAll()
    }

    static func add(_ binding: AnyCancellable) {
        guard let current = BindingGroup.current else {
            fatalError("Bindings must be in a capture group")
        }
        
        current.add(binding)
    }
    
    init() {
    }
    
    init(_ block: () -> Void) {
        capture(block)
    }
}

protocol BindingGroupProtocol { }

extension BindingGroupProtocol where Self: BindingGroup {
    static func add(_ binding: Cancellable) {
        Self.add(AnyCancellable({ binding.cancel() }))
    }
}

extension BindingGroup: BindingGroupProtocol { }

public protocol BindableView {
    associatedtype Element
    
    func bind(to element: Element)
}

/// a ViewModelItem that has an associated BindableView, such as a view model item for a UITableViewCell
public protocol BindableViewModelItem {
    /// The View type (or base type) associated with this VIew Model Item
    associatedtype View: BindableView where View.Element == Self
    
    /// returns the view type to be used for a specific element. By default this will return the associated type's type.
    ///
    ///  override this when you need to associate multiple bindable views with a single list of ViewModelItems.
    ///
    /// - Parameter element: the element to return the
    ///
    static func bindableViewTypeFor(_ element: Self) -> View.Type
}

extension BindableViewModelItem {
    public static func bindableViewTypeFor(_ element: Self) -> View.Type {
        return View.self
    }
}
