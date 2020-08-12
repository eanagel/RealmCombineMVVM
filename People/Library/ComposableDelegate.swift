//
//  ComposableDelegate.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation

public class ComposableDelegate<Delegate: NSObjectProtocol>: NSObject {
    public let nextDelegate: Delegate?
    
    override public func responds(to aSelector: Selector!) -> Bool {
        if super.responds(to: aSelector) {
            return true
        }
        
        if let nextDelegateObject = self.nextDelegate as? NSObject {
            if nextDelegateObject.responds(to: aSelector) {
                return true
            }
        }

        return false
    }
    
    public override func forwardingTarget(for aSelector: Selector!) -> Any? {
        if let nextDelegateObject = self.nextDelegate as? NSObject {
            if nextDelegateObject.responds(to: aSelector) {
                return nextDelegateObject
            }
        }
        
        return super.forwardingTarget(for: aSelector)
    }
    
    init(nextDelegate: Delegate? = nil) {
        if let nextDelegate = nextDelegate, (nextDelegate as? NSObject) == nil {
            fatalError("nextDelegate must be an NSObject subclass")
        }
        self.nextDelegate = nextDelegate
    }
}

