//
//  PickerViewBinding.swift
//  People
//
//  Created by Ethan Nagel on 8/18/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine
import RealmSwift

public typealias UIPickerViewDataSourceAndDelegate = UIPickerViewDataSource & UIPickerViewDelegate

public func *=(_ lhs: UIPickerView, _ rhs: PickerViewComponentBinding) {
    lhs.dataSource = rhs
    lhs.delegate = rhs
    rhs.pickerView = lhs
    BindingGroup.add(rhs)
}

//public func *=<Element: BindableViewModelItem, RHS: ObservableArray>(_ lhs: UITableView, _ rhs: RHS) where RHS.Element == Element, Element.View: UITableViewCell {
//    lhs *= TableViewSectionBinding.items(rhs)
//}
//
//public func *=<P: Publisher, Element: BindableViewModelItem>(_ lhs: UITableView, _ rhs: P) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.View: UITableViewCell {
//    lhs *= TableViewSectionBinding.items(rhs)
//}
//
//public func *=<P: Publisher, Element: UITableViewCell>(_ lhs: UITableView, _ rhs: P) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
//    lhs *= TableViewSectionBinding.items(rhs)
//}
//
//public func *=(_ lhs: UITableView, _ rhs: TableViewBinding) {
//    rhs.tableView = lhs
//    lhs.dataSource = rhs
//    lhs.delegate = rhs
//    BindingGroup.add(rhs)
//}
//
//public func *=<P: Publisher>(_ lhs: UITableView, _ rhs: P)  where P.Output == RealmCollectionChange<[TableViewSectionBinding]>, P.Failure == Never {
//    lhs *= TableViewBinding.sections(rhs)
//}
//
//public func *=(_ lhs: UITableView, _ rhs: [TableViewSectionBinding]) {
//    lhs *= TableViewBinding.sections(rhs)
//}


public protocol PickerViewElement {
    associatedtype Content
    
    var pickerTitle: Content? { get }
}

public class PickerViewBindingBase: ComposableDelegate<UIPickerViewDataSourceAndDelegate>, UIPickerViewDataSourceAndDelegate {
    private var _onInitialized: [() -> Void] = []
    
    /// executes block once the pickerView has been assigned. If the pickerView has already been assigned, the block is executed immediately
    /// - Parameter block: block to execute once the pickerView has been set
    public func onInitialized(_ block: @escaping () -> Void) {
        if self.pickerView != nil {
            block()
        } else {
            _onInitialized.append(block)
        }
    }
    
    /// gets or sets the pickerView associated with this PickerViewBinding. Must be set in order for the binding to work effectively.
    /// forwards the pickerView to the next delegate if they are chained.
    public var pickerView: UIPickerView? {
        didSet {
            (self.nextDelegate as? PickerViewBindingBase)?.pickerView = self.pickerView
            
            if self.pickerView != nil && !_onInitialized.isEmpty {
                _onInitialized.forEach({ $0() })
                _onInitialized = []
            }
        }
    }
    
    public override func responds(to aSelector: Selector!) -> Bool {
        let result = super.responds(to: aSelector)
        
        print("PickerViewBinding.responds(to: \(aSelector!)) = \(result)")
        
        return result
    }
    
    public func cancel() {
    }
    
    public override init(nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) {
        super.init(nextDelegate: nextDelegate)
    }
    
    public func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return nextDelegate?.numberOfComponents(in: pickerView) ?? 1
    }
    
    public func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return nextDelegate?.pickerView(pickerView, numberOfRowsInComponent: component) ?? 0
    }
    
}

public class PickerViewComponentBinding: PickerViewBindingBase {
    /// The component number associated with this TableViewSectionBinding. This is managed by
    /// TableViewBinding.section(...).
    public var component: Int = 0 {
        didSet { (self.nextDelegate as? PickerViewComponentBinding)?.component = component }
    }
    
    public func eraseToAnyComponentBinding() -> PickerViewComponentBinding {
        return PickerViewComponentBinding(nextDelegate: self)
    }
}

extension PickerViewComponentBinding: Cancellable {
    // Classes that implement UIPickerViewDataSource or Delegate methods cannot be generic
    // In order to accomplish this we use a content provider along with generic constructors
    // on the classes for each type.
    
    private class ContentProvider<Content> {
        private let _contentForRow: (Int, Content?) -> Content?
        private let _numberOfRows: () -> Int
        private var _bindToPublisher: (() -> AnyCancellable)!
        private var binding: AnyCancellable?
        public var onReloadComponent: (() -> Void)? {
            didSet {
                // bind to the publisher once onReloadComponent has been set
                if binding == nil {
                    binding = _bindToPublisher()
                }
            }
        }
        
        init<P: Publisher, Element>(_ publisher: P, contentForElement: @escaping (Element, Content?) -> Content?) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            var items: [Element] = []
            
            self._contentForRow = { contentForElement(items[$0], $1) }
            self._numberOfRows = { items.count }
            
            self._bindToPublisher = {
                return publisher.currentValuePublisher().sink { [weak self] (newItems) in
                    guard let self = self else { return }
                    
                    items = newItems
                    self.onReloadComponent?()
                }
            }
        }
        
        convenience init<P: Publisher, Element>(_ publisher: P, contentForElement: @escaping (Element) -> Content?) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.init(publisher, contentForElement: { (element, _) in contentForElement(element) })
        }

        func cancel() {
            binding?.cancel()
            binding = nil
        }
                
        public func contentForRow(_ row: Int, reusing: Content? = nil) -> Content? {
            return _contentForRow(row, reusing)
        }
        
        public var numberOfRows: Int { _numberOfRows() }
    }
    
    private class StringItems: PickerViewComponentBinding {
        private var contentProvider: ContentProvider<String>?
        
        init<P: Publisher, Element>(_ publisher: P, contentForElement: @escaping (Element) -> String?, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = ContentProvider(publisher, contentForElement: contentForElement)
            super.init(nextDelegate: nextDelegate)
            
            self.contentProvider?.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        init<P: Publisher, Element>(_ publisher: P, _ contentProvider: ContentProvider<String>, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = contentProvider
            super.init(nextDelegate: nextDelegate)
            
            contentProvider.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        override func cancel() {
            contentProvider?.cancel()
            contentProvider = nil
        }
        
        public func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, titleForRow: row, forComponent: component)
            }
            
            return contentProvider?.contentForRow(row)
        }
        
        override func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            contentProvider?.numberOfRows ?? 0
        }
    }
    
    private class AttributedStringItems: PickerViewComponentBinding {
        private var contentProvider: ContentProvider<NSAttributedString>?
        
        init<P: Publisher, Element>(_ publisher: P, contentForElement: @escaping (Element) -> NSAttributedString?, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = ContentProvider(publisher, contentForElement: contentForElement)
            super.init(nextDelegate: nextDelegate)
            
            self.contentProvider?.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        init<P: Publisher, Element>(_ publisher: P, _ contentProvider: ContentProvider<NSAttributedString>, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = contentProvider
            super.init(nextDelegate: nextDelegate)
            
            contentProvider.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        override func cancel() {
            contentProvider?.cancel()
            contentProvider = nil
        }
        
        public func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, attributedTitleForRow: row, forComponent: component)
            }
            
            return contentProvider?.contentForRow(row)
        }
        
        override func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            contentProvider?.numberOfRows ?? 0
        }
    }
    
    private class ViewItems: PickerViewComponentBinding {
        private var contentProvider: ContentProvider<UIView>?
        
        init<P: Publisher, Element>(_ publisher: P, contentForElement: @escaping (Element, UIView?) -> UIView?, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = ContentProvider(publisher, contentForElement: contentForElement)
            super.init(nextDelegate: nextDelegate)
            
            self.contentProvider?.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        init<P: Publisher, Element>(_ publisher: P, _ contentProvider: ContentProvider<UIView>, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.contentProvider = contentProvider
            super.init(nextDelegate: nextDelegate)
            
            contentProvider.onReloadComponent = { [weak self] in
                guard let self = self, let pickerView = self.pickerView else { return }
                pickerView.reloadComponent(self.component)
            }
        }
        
        override func cancel() {
            contentProvider?.cancel()
            contentProvider = nil
        }
        
        func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, viewForRow: row, forComponent: component, reusing: view) ?? UIView()
            }
            
            return contentProvider?.contentForRow(row, reusing: view) ?? UIView()
        }
        
        override func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            contentProvider?.numberOfRows ?? 0
        }
    }
    
    // String
    
    public static func items<Element, P: Publisher>(_ publisher: P, contentForElement: @escaping (Element) -> String?) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
        return StringItems(publisher, contentForElement: contentForElement)
    }
    
    public static func items<Element: PickerViewElement, P: Publisher>(_ publisher: P) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.Content == String {
        return Self.items(publisher, contentForElement: { $0.pickerTitle })
    }
    
    public static func items<Element, OA: ObservableArray>(_ items: OA, contentForElement: @escaping (Element) -> String?) -> PickerViewComponentBinding where OA.Element == Element {
        return Self.items(items.changeSetPublisher, contentForElement: contentForElement)
    }

    public static func items<Element: PickerViewElement, OA: ObservableArray>(_ items: OA) -> PickerViewComponentBinding where Element.Content == String, OA.Element == Element {
        return Self.items(items.changeSetPublisher)
    }

    public static func items<Element>(_ items: [Element], contentForElement: @escaping (Element) -> String?) -> PickerViewComponentBinding {
        return Self.items(Just(.initial(items)), contentForElement: contentForElement)
    }
    
    public static func items<Element: PickerViewElement>(_ items: [Element]) -> PickerViewComponentBinding where Element.Content == String {
        return Self.items(Just(.initial(items)))
    }
    
    // NSAttributedString

    public static func items<Element, P: Publisher>(_ publisher: P, contentForElement: @escaping (Element) -> NSAttributedString?) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
        return AttributedStringItems(publisher, contentForElement: contentForElement)
    }

    public static func items<Element: PickerViewElement, P: Publisher>(_ publisher: P) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.Content == NSAttributedString {
        return Self.items(publisher, contentForElement: { $0.pickerTitle })
    }

    public static func items<Element>(_ items: [Element], contentForElement: @escaping (Element) -> NSAttributedString?) -> PickerViewComponentBinding {
        return Self.items(Just(.initial(items)), contentForElement: contentForElement)
    }

    public static func items<Element: PickerViewElement>(_ items: [Element]) -> PickerViewComponentBinding where Element.Content == NSAttributedString {
        return Self.items(Just(.initial(items)))
    }

    // UIView

    public static func items<Element, P: Publisher>(_ publisher: P, contentForElement: @escaping (Element, UIView?) -> UIView) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
        return ViewItems(publisher, contentForElement: contentForElement)
    }

    public static func items<Element: BindableViewModelItem, P: Publisher>(_ publisher: P) -> PickerViewComponentBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.View: UIView {
        return Self.items(publisher, contentForElement: { (element, reuseView) in
            let view = (reuseView as? Element.View) ?? Element.bindableViewTypeFor(element).init()

            view.bind(to: element)

            return view
        })
    }

    public static func items<Element>(_ items: [Element], contentForElement: @escaping (Element, UIView?) -> UIView) -> PickerViewComponentBinding {
        return Self.items(Just(.initial(items)), contentForElement: contentForElement)
    }

    public static func items<Element: BindableViewModelItem>(_ items: [Element]) -> PickerViewComponentBinding where Element.View: UIView {
        return Self.items(Just(.initial(items)))
    }
}

extension PickerViewComponentBinding {
    private class DidSelectRow: PickerViewComponentBinding {
        private let action: (Int) -> Void
        
        init(_ action: @escaping (Int) -> Void, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) {
            self.action = action
            super.init(nextDelegate: nextDelegate)
        }
        
        func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
            guard component == self.component else {
                nextDelegate?.pickerView?(pickerView, didSelectRow: row, inComponent: component)
                return
            }
            
            self.action(row)
        }
    }
    
    public func didSelectRow(_ action: @escaping (Int) -> Void) ->PickerViewComponentBinding {
        return DidSelectRow(action, nextDelegate: self)
    }
}
