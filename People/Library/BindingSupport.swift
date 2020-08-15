//
//  BindingSupport.swift
//  People
//
//  Created by Ethan Nagel on 8/10/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import Combine
import UIKit

func *= <O, T, P>(lhs: Binding<O, T>, rhs: P) where P: Publisher, P.Output == T {
    BindingGroup.add(rhs.sink(lhs))
}

func *= <O, T, P>(lhs: Binding<O, T?>, rhs: P) where P: Publisher, P.Output == T {
    // this flavor allows us to bind a nullable value to a non-nullable value without coercion
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
    fileprivate func _sink<O: AnyObject>(object: O, setValue: @escaping (inout O, Output) -> Void) -> AnyCancellable {
        var sink: AnyCancellable?
            
        sink = self.sink(receiveCompletion: { (_) in }) { [weak object, weak sink] (value) in
            guard var object = object else {
                sink?.cancel() // cancel the sink if the object no longer exists
                sink = nil
                return
            }
            
            setValue(&object, value)
        }
        
        return sink!
    }
    
    func sink<O: AnyObject>(_ binding: Binding<O,Output>) -> AnyCancellable {
        return _sink(object: binding.object, setValue: { $0[keyPath: binding.keyPath] = $1 })
    }
    
    func sink<O: AnyObject>(_ binding: Binding<O,Output?>) -> AnyCancellable {
        return _sink(object: binding.object, setValue: { $0[keyPath: binding.keyPath] = $1 })
    }
}


public class BindingGroup {
    private var items = Set<AnyCancellable>()
    
    public static var current: BindingGroup? = nil
    
    public func capture<T>(_ block: () -> T) -> T {
        let temp = BindingGroup.current
        BindingGroup.current = self
        
        let result = block()
        
        BindingGroup.current = temp
        
        return result
    }
    
    public func add(_ object: AnyObject) {
        
        let cancellable: AnyCancellable = {
            
            // if object is already AnyCancellable, then we are all set...
            
            if let cancellable = object as? AnyCancellable {
                return cancellable
            }
            
            // if we respond to the Cancellable protocol, go ahead and wrap in AnyCancellable...
            
            if let cancellable = object as? Cancellable {
                return AnyCancellable { cancellable.cancel() }
            }
            
            // Otherwise wrap an arbitrary value in AnyCancellable...
            // We are using retained to create a retain cycle that matches the lifetime of the
            // AnyCancellable.
            
            var retained: AnyObject? = object
            
            let cancellable = AnyCancellable {
                if (retained != nil) {
                    retained = nil
                }
            }
            
            return cancellable
        }()
        
        items.insert(cancellable)
    }
        
    public static func add(_ binding: AnyObject) {
        guard let current = BindingGroup.current else {
            fatalError("Bindings must be in a capture group")
        }
        
        current.add(binding)
    }
    
    public func clear() {
        items.removeAll()
    }

    public init() {
    }
    
    public init(_ block: () -> Void) {
        capture(block)
    }
}

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
