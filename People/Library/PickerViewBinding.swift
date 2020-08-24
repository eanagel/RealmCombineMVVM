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
}

extension PickerViewComponentBinding: Cancellable {
    private class Items<Element, Content>: PickerViewComponentBinding {
        private var items: [Element]
        private let contentForElement: (Element, Content?) -> Content?
        private var binding: AnyCancellable?

        init<P: Publisher>(_ publisher: P, contentForElement: @escaping (Element, Content?) -> Content?, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            
            self.items = []
            self.contentForElement = contentForElement
            super.init(nextDelegate: nextDelegate)
            
            self.binding = publisher.currentValuePublisher().sink { [weak self] (newItems) in
                guard let self = self else { return }
                
                self.items = newItems
                self.pickerView?.reloadComponent(self.component)
            }
        }
        
        convenience init<P: Publisher>(_ publisher: P, contentForElement: @escaping (Element) -> Content?, nextDelegate: UIPickerViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.init(publisher, contentForElement: { (element, _) in contentForElement(element) })
        }

        override func cancel() {
            binding?.cancel()
            binding = nil
            super.cancel()
        }
                
        public func contentForRow(_ row: Int, reusing: Content? = nil) -> Content? {
            return contentForElement(items[row], reusing)
        }
        
        // we can only override existing methods here, we cannot declare new ones...
        
        override func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
            return items.count
        }
    }
    
    private class StringItems<Element>: Items<Element, String> {
        @objc func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, titleForRow: row, forComponent: component)
            }
        
            return contentForRow(row)
        }
    }
    
    private class AttributedStringItems<Element>: Items<Element, NSAttributedString> {
        @objc func pickerView(_ pickerView: UIPickerView, attributedTitleForRow row: Int, forComponent component: Int) -> NSAttributedString? {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, attributedTitleForRow: row, forComponent: component)
            }
            
            return contentForRow(row)
        }
    }
    
    private class ViewItems<Element>: Items<Element, UIView> {
        @objc func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
            guard component == self.component else {
                return nextDelegate?.pickerView?(pickerView, viewForRow: row, forComponent: component, reusing: view) ?? UIView()
            }
            
            return contentForRow(row, reusing: view) ?? UIView()
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

    public static func items<Element, OA: ObservableArray>(_ items: OA, contentForElement: @escaping (Element) -> NSAttributedString?) -> PickerViewComponentBinding where OA.Element == Element {
        return Self.items(items.changeSetPublisher, contentForElement: contentForElement)
    }

    public static func items<Element: PickerViewElement, OA: ObservableArray>(_ items: OA) -> PickerViewComponentBinding where Element.Content == NSAttributedString, OA.Element == Element {
        return Self.items(items.changeSetPublisher)
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
    
    public static func items<Element, OA: ObservableArray>(_ items: OA, contentForElement: @escaping (Element, UIView?) -> UIView) -> PickerViewComponentBinding where OA.Element == Element {
        return Self.items(items.changeSetPublisher, contentForElement: contentForElement)
    }

    public static func items<Element: BindableViewModelItem, OA: ObservableArray>(_ items: OA) -> PickerViewComponentBinding where Element.View: UIView, OA.Element == Element {
        return Self.items(items.changeSetPublisher)
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
