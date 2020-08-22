//
//  TableViewBinding.swift
//  People
//
//  Created by Ethan Nagel on 8/11/20.
//  Copyright © 2020 Nagel Technologies. All rights reserved.
//

import Foundation
import UIKit
import Combine
import RealmSwift

public typealias UITableViewDataSourceAndDelegate = UITableViewDataSource & UITableViewDelegate

public func *=(_ lhs: UITableView, _ rhs: TableViewSectionBinding) {
    rhs.tableView = lhs
    lhs.dataSource = rhs
    lhs.delegate = rhs
    BindingGroup.add(rhs)
}

public func *=<Element: BindableViewModelItem, RHS: ObservableArray>(_ lhs: UITableView, _ rhs: RHS) where RHS.Element == Element, Element.View: UITableViewCell {
    lhs *= TableViewSectionBinding.items(rhs)
}

public func *=<P: Publisher, Element: BindableViewModelItem>(_ lhs: UITableView, _ rhs: P) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.View: UITableViewCell {
    lhs *= TableViewSectionBinding.items(rhs)
}

public func *=<P: Publisher, Element: UITableViewCell>(_ lhs: UITableView, _ rhs: P) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
    lhs *= TableViewSectionBinding.items(rhs)
}

public func *=(_ lhs: UITableView, _ rhs: TableViewBinding) {
    rhs.tableView = lhs
    lhs.dataSource = rhs
    lhs.delegate = rhs
    BindingGroup.add(rhs)
}

public func *=<P: Publisher>(_ lhs: UITableView, _ rhs: P)  where P.Output == RealmCollectionChange<[TableViewSectionBinding]>, P.Failure == Never {
    lhs *= TableViewBinding.sections(rhs)
}

public func *=(_ lhs: UITableView, _ rhs: [TableViewSectionBinding]) {
    lhs *= TableViewBinding.sections(rhs)
}

/// Base class fort TableViewBinding and TableViewSectionBinding
public class TableViewBindingBase: ComposableDelegate<UITableViewDataSourceAndDelegate>, UITableViewDataSourceAndDelegate, Cancellable {
    private var _onInitialized: [() -> Void] = []
    
    /// executes block once the tableView has been assigned. If the tableView has already been assigned, the block is executed immediately
    /// - Parameter block: block to execute once the tableView has been set
    public func onInitialized(_ block: @escaping () -> Void) {
        if self.tableView != nil {
            block()
        } else {
            _onInitialized.append(block)
        }
    }
    
    /// gets or sets the tableView associated with this TableViewBinding. Must be set in order for the binding to work effectively.
    /// forwards the tableView to the next delegate if they are chained.
    public var tableView: UITableView? {
        didSet {
            (self.nextDelegate as? TableViewBindingBase)?.tableView = self.tableView
            
            if self.tableView != nil && !_onInitialized.isEmpty {
                _onInitialized.forEach({ $0() })
                _onInitialized = []
            }
        }
    }
    
    public func cancel() {
    }
    
    fileprivate override init(nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
        super.init(nextDelegate: nextDelegate)
    }
    
    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.nextDelegate?.tableView(tableView, numberOfRowsInSection: section) ?? 0
    }
    
    public func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return self.nextDelegate?.tableView(tableView, cellForRowAt: indexPath) ?? UITableViewCell()
    }
}

/// Represents a TableViewBinding for a specific section. This may be used directly as the DataSource and Delegate for
/// single-section tables or as a single section for TableViewSection.sections(...).
public class TableViewSectionBinding: TableViewBindingBase {
    
    /// The section number associated with this TableViewSectionBinding. This is managed by
    /// TableViewBinding.section(...).
    public var section: Int = 0 {
        didSet { (self.nextDelegate as? TableViewSectionBinding)?.section = section }
    }
    
    /// Method to call when batch updates are performed by a TableViewSectionBinding. This is used by
    /// TableViewBinding.section(...) to coordinate updates
    public var performBatchUpdates: (_ tableView: UITableView, _ updates: @escaping () -> Void) -> Void = TableViewSectionBinding.defaultPerformBatchUpdates {
        didSet { (self.nextDelegate as? TableViewSectionBinding)?.performBatchUpdates = self.performBatchUpdates }
    }
    
    /// Method to call when data should be reloaded by a TableViewSectionBinding. This is used by
    /// TableViewBinding.section(...) to coordinate updates
    public var reloadData: (_ tableView: UITableView, _ apply: @escaping () -> Void) -> Void = TableViewSectionBinding.defaultReloadData {
        didSet { (self.nextDelegate as? TableViewSectionBinding)?.reloadData = self.reloadData }
    }
        
    /// default method called by performBatchUpdates
    public static func defaultPerformBatchUpdates(_ tableView: UITableView, _ updates: () -> Void) {
        tableView.performBatchUpdates(updates)
    }
    
    /// default method called by reloadData
    public static func defaultReloadData(_ tableView: UITableView, _ apply: () -> Void) {
        apply()
        tableView.reloadData()
    }
}

extension TableViewSectionBinding {
    private class Items<Element>: TableViewSectionBinding {
        private var items: [Element]
        private let cellForItemAt: (UITableView, IndexPath, Element) -> UITableViewCell
        private var binding: AnyCancellable?
        
        init<P: Publisher>(_ publisher: P, cellForItem: @escaping (UITableView, IndexPath, Element) -> UITableViewCell, nextDelegate: UITableViewDataSourceAndDelegate? = nil) where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            self.items = []
            self.cellForItemAt = cellForItem
            
            super.init(nextDelegate: nextDelegate)
                        
            self.onInitialized { [weak self] in
                guard let self = self else { return }
                
                self.binding = publisher.sink { [weak self] (changes) in
                    guard let self = self, let tableView = self.tableView else { return }
                    let section = self.section

                    switch(changes) {
                    case .initial(let items):
                        self.reloadData(tableView, { self.items = items })
                        
                    case .update(let items, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                        self.performBatchUpdates(tableView) {
                            tableView.insertRows(at: insertions.map({ IndexPath(item: $0, section: section) }), with: .automatic)
                            tableView.deleteRows(at: deletions.map({ IndexPath(item: $0, section: section) }), with: .automatic)
                            tableView.reloadRows(at: modifications.map({ IndexPath(item: $0, section: section) }), with: .automatic)
                            self.items = items
                        }
                        
                    case .error:
                        break
                    }
                }
            }
        }
        
        convenience init<P>(_ publisher: P, nextDelegate: UITableViewDataSourceAndDelegate? = nil) where Element: BindableViewModelItem, Element.View: UITableViewCell, P: Publisher, P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            let cellForItem: (UITableView, IndexPath, Element) -> UITableViewCell = { (tableView, indexPath, item) in
                let cellType = Element.bindableViewTypeFor(item)
                let cell = tableView.dequeueReusableCell(withIdentifier: String(describing: cellType.self), for: indexPath) as! Element.View
                
                cell.bind(to: item)
                
                return cell
            }
            
            self.init(publisher, cellForItem: cellForItem, nextDelegate: nextDelegate)
        }

        convenience init<P: Publisher>(_ publisher: P, nextDelegate: UITableViewDataSourceAndDelegate? = nil) where Element: UITableViewCell, P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
            let cellForItem: (UITableView, IndexPath, Element) -> UITableViewCell = { (tableView, indexPath, item) in
                return item
            }
            
            self.init(publisher, cellForItem: cellForItem, nextDelegate: nextDelegate)
        }

        deinit {
            cancel()
        }
        
        override public func cancel() {
            binding?.cancel()
            binding = nil
            super.cancel()
        }
        
        public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            guard section == self.section else {
                return self.nextDelegate?.tableView(tableView, numberOfRowsInSection: section) ?? 0
            }
            
            return self.items.count
        }
        
        public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            guard indexPath.section == self.section else {
                return self.nextDelegate?.tableView(tableView, cellForRowAt: indexPath) ?? UITableViewCell()
            }
    
            guard let tableView = self.tableView else { return UITableViewCell() }
            
            let cell = self.cellForItemAt(tableView, indexPath, self.items[indexPath.row])
                        
            return cell
        }
    }
    
    /// Dynamically binds to a publisher of RealmCollectionChanges for an array of BindableViewModelItems.
    /// - Parameter publisher: a publisher that outputs RealCollectionChange<[Element]> where the Element is a BindableViewModelItem
    /// - Returns: a dynamic TableViewSectionBinding for the published items
    public static func items<P: Publisher, Element: BindableViewModelItem>(_ publisher: P) -> TableViewSectionBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never, Element.View: UITableViewCell {
        return Items(publisher)
    }
    
    /// Dynamically binds to a publisher or RealmCollectionChanges for an array of UITableViewCells.
    /// - Parameter publisher: a publisher that outputs RealCollectionChange<[UITableViewCell]>
    /// - Returns: a dynamic TableViewSectionBinding for the published cells
    public static func items<P: Publisher, Element: UITableViewCell>(_ publisher: P) -> TableViewSectionBinding where P.Output == RealmCollectionChange<[Element]>, P.Failure == Never {
        return Items<Element>(publisher)
    }
    
    /// Dynamically binds to changes in items ViewModelArray wherethe elements conform to BindableViewModelItem
    /// - Parameter items: an ObservableArray of items to bind to
    /// - Returns: a dynamic TableViewSectionBinding for the published items
    public static func items<Element: BindableViewModelItem, I: ObservableArray>(_ items: I) -> TableViewSectionBinding where I.Element == Element, Element.View: UITableViewCell {
        return Items(items.changeSetPublisher)
    }
    
    
    /// displays a static array of BindableViewModelItems
    /// - Parameter items: the BindableViewModelsItems to bind
    /// - Returns: a TableViewSectionBinding for the published items
    public static func items<Element: BindableViewModelItem>(_ items: Element...) -> TableViewSectionBinding where Element.View: UITableViewCell {
        return Items(Just(RealmCollectionChange<[Element]>.initial(items)))
    }
    
    /// displays a static array of UITableViewCells
    /// - Parameter items: the cells for the section
    /// - Returns: a TableViewSectionBinding for the published cells
    public static func items<Element: UITableViewCell>(_ items: Element...) -> TableViewSectionBinding {
        return Items<Element>(Just(RealmCollectionChange<[Element]>.initial(items)))
    }
}

extension TableViewSectionBinding { // Header/Footer Title
    private class HeaderTitle: TableViewSectionBinding {
        let title: String?
        
        init(_ title: String?, nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
            self.title = title
            super.init(nextDelegate: nextDelegate)
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            guard section == self.section else {
                return self.nextDelegate?.tableView?(tableView, titleForHeaderInSection: section)
            }
            
            return title
        }
    }
    
    private class FooterTitle: TableViewSectionBinding {
        let title: String?
        
        init(_ title: String?, nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
            self.title = title
            super.init(nextDelegate: nextDelegate)
        }
        
        func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
            guard section == self.section else {
                return self.nextDelegate?.tableView?(tableView, titleForFooterInSection: section)
            }
            
            return title
        }
    }
    
    
    /// sets the header title to be used for this section
    /// - Parameter title: the title for thie section. set to nil to suppress display of the section
    /// - Returns: a new instance ot TableViewSectionBinding
    public static func headerTitle(_ title: String?) -> TableViewSectionBinding {
        return HeaderTitle(title)
    }
    
    /// sets the header title to be used for this section
    /// - Parameter title: the title for thie section. set to nil to suppress display of the section
    /// - Returns: a new instance ot TableViewSectionBinding
    public func headerTitle(_ title: String?) -> TableViewSectionBinding {
        return HeaderTitle(title, nextDelegate: self)
    }
    
    /// sets the footer title to be used for this section
    /// - Parameter title: the title for thie section. set to nil to suppress display of the section
    /// - Returns: a new instance ot TableViewSectionBinding
    public static func footerTitle(_ title: String?) -> TableViewSectionBinding {
        return FooterTitle(title)
    }
    
    /// sets the footer title to be used for this section
    /// - Parameter title: the title for thie section. set to nil to suppress display of the section
    /// - Returns: a new instance ot TableViewSectionBinding
    public func footerTitle(_ title: String?) -> TableViewSectionBinding {
        return FooterTitle(title, nextDelegate: self)
    }
}

extension TableViewSectionBinding { // cell selection
    private class DidSelectRow: TableViewSectionBinding {
        private let action: (IndexPath) -> Void
        
        init(_ action: @escaping (IndexPath) -> Void, nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
            self.action = action
            super.init(nextDelegate: nextDelegate)
        }
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            guard indexPath.section == section else {
                nextDelegate?.tableView?(tableView, didSelectRowAt: indexPath)
                return
            }
            
            self.action(indexPath)
        }
    }
    
    /// executes action when the row was selected for the current section
    /// - Parameter action: the title for thie section. set to nil to suppress display of the section
    /// - Returns: a new instance ot TableViewSectionBinding
    public func didSelectRow(_ action: @escaping (IndexPath) -> Void) -> TableViewSectionBinding {
        return DidSelectRow(action, nextDelegate: self)
    }
}

extension TableViewSectionBinding { // Row Height
    private class RowHeight: TableViewSectionBinding {
        private let action: (IndexPath) -> CGFloat
        
        init(_ action: @escaping (IndexPath) -> CGFloat, nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
            self.action = action
            super.init(nextDelegate: nextDelegate)
        }

        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            guard indexPath.section == section else {
                return nextDelegate?.tableView?(tableView, heightForRowAt: indexPath) ?? tableView.rowHeight
            }
            
            return action(indexPath)
        }
    }
    
    /// executes action to determine the row height for the cell
    /// - Parameter action: an action that returns a cell height (including UITableView.automaticDimension)
    /// - Returns: a new instance ot TableViewSectionBinding
    public func rowHeight(_ action: @escaping (IndexPath) -> CGFloat) -> TableViewSectionBinding {
        return RowHeight(action, nextDelegate: self)
    }
    
    /// returns the indicated the row height for the cell
    /// - Parameter rowHeight: an action that returns a cell height (including UITableView.automaticDimension)
    /// - Returns: a new instance ot TableViewSectionBinding
    public func rowHeight(_ rowHeight: CGFloat) -> TableViewSectionBinding {
        return RowHeight({ _ in rowHeight }, nextDelegate: self)
    }
    
    /// instructs the system to use auto layout to calculate row height
    /// - Returns: a new instance ot TableViewSectionBinding
    public func automaticRowHeight() -> TableViewSectionBinding {
        return RowHeight({ _ in UITableView.automaticDimension }, nextDelegate: self)
    }
}

public class TableViewBinding: TableViewBindingBase {
}

extension TableViewBinding {
    fileprivate class Default: TableViewBinding {
        let defaultDelegate: NSObject
        
        init(_ defaultDelegate: NSObject, nextDelegate: UITableViewDataSourceAndDelegate? = nil) {
            self.defaultDelegate = defaultDelegate
            super.init(nextDelegate: nextDelegate)
        }
        
        override public func responds(to aSelector: Selector!) -> Bool {
            if super.responds(to: aSelector) {
                return true
            }
            
            if self.defaultDelegate.responds(to: aSelector) {
                return true
            }
            
            return false
        }
        
        public override func forwardingTarget(for aSelector: Selector!) -> Any? {
            if super.responds(to: aSelector) {
                return super.forwardingTarget(for: aSelector)
            }
            
            return self.defaultDelegate.forwardingTarget(for: aSelector)
        }
    }
    
    /// The passed delegate will be called for any unhandled UITableViewDataSource  or UITableViewDelegate methods
    public func `default`(_ defaultDelegate: NSObject) -> TableViewBinding {
        return Default(defaultDelegate, nextDelegate: self)
    }
}

extension TableViewBinding {
    private class Sections: TableViewBinding {
        private var sections: [TableViewSectionBinding] {
            willSet {
                for section in self.sections {
                    section.tableView = nil
                    section.section = 0
                    section.performBatchUpdates = TableViewSectionBinding.defaultPerformBatchUpdates
                    section.reloadData = TableViewSectionBinding.defaultReloadData
                }
            }
            didSet {
                for (index, section) in self.sections.enumerated() {
                    section.tableView = self.tableView
                    section.section = index
                    section.performBatchUpdates = { [weak self] (tableView, updates) in
                        guard let self = self else { return }
                        self.performBatchUpdates(updates)
                    }
                    section.reloadData = { [weak self] (tableView, apply) in
                        guard let self = self else { return }
                        self.reloadData(apply)
                    }
                }
            }
        }
        
        public override var tableView: UITableView? {
            didSet {
                for section in self.sections {
                    section.tableView = self.tableView
                }
            }
        }
    
        private var bindings = Set<AnyCancellable>()
        
        private var deferredUpdates: [() -> Void] = []
        private func performBatchUpdates(_ updates: @escaping () -> Void) {
            // collect all updates in a runloop into a group and do them in the next runloop...
            
            if deferredUpdates.isEmpty {
                DispatchQueue.main.async {
                    if !self.deferredReloadData.isEmpty {
                        print("TableViewBinding.Sections Warning: performing updates while a reload data is pending")
                    }
                    
                    let updates = self.deferredUpdates
                    self.deferredUpdates = []
                    
                    self.tableView?.performBatchUpdates({
                        updates.forEach({ $0() })
                    }, completion: nil)
                }
            }
            
            deferredUpdates.append(updates)
        }
        
        private var deferredReloadData: [() -> Void] = []
        
        private func reloadData(_ apply: @escaping () -> Void) {
            if deferredReloadData.isEmpty {
                DispatchQueue.main.async {
                    if !self.deferredUpdates.isEmpty {
                        print("TableViewBinding.Sections Warning: performing reload data while updates are pending")
                    }
                    
                    let applies = self.deferredReloadData
                    self.deferredReloadData = []
                    
                    applies.forEach({ $0() })
                    self.tableView?.reloadData()
                }
            }
            
            deferredReloadData.append(apply)
        }
        
        init<P>(_ publisher: P, nextDelegate: UITableViewDataSourceAndDelegate? = nil) where P: Publisher, P.Output == RealmCollectionChange<[TableViewSectionBinding]>, P.Failure == Never {
            self.sections = []
            
            super.init(nextDelegate: nextDelegate)
            
            // we need to wait to start receiving events until the tableView has been set. We are using a connectable to
            // accomplish this...
            
            let connectable = publisher.makeConnectable()
            self.onInitialized { [weak self] in
                guard let self = self else { return }
                connectable.connect().store(in: &self.bindings)
            }
            
            connectable.sink { [weak self] (changes) in
                guard let self = self, let tableView = self.tableView else { return }
                
                switch(changes) {
                case .initial(let sections):
                    self.reloadData({ self.sections = sections })
                    
                case .update(let sections, deletions: let deletions, insertions: let insertions, modifications: let modifications):
                    self.performBatchUpdates {
                        tableView.insertSections(IndexSet(insertions), with: .automatic)
                        tableView.deleteSections(IndexSet(deletions), with: .automatic)
                        tableView.reloadSections(IndexSet(modifications), with: .automatic)
                        self.sections = sections
                    }
                    
                case .error:
                    break
                }
            }.store(in: &bindings)
        }

        deinit {
            cancel()
        }
        
        override public func cancel() {
            bindings.removeAll()
            super.cancel()
        }
        
        func numberOfSections(in tableView: UITableView) -> Int {
            return self.sections.count
        }
        
        fileprivate func forward<T>(_ section: Int, _ action: (UITableViewDataSourceAndDelegate) -> T) -> T {
            return action(self.sections[section])
        }
        
        // UITableViewDelegate forwarding
        
        public override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
            return forward(section, { $0.tableView(tableView, numberOfRowsInSection: section) })
        }
        
        public override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
            return forward(indexPath.section, { $0.tableView(tableView, cellForRowAt: indexPath) })
        }
        
        func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
            return forward(section, { $0.tableView?(tableView, titleForHeaderInSection: section) })
        }
        
        func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
            forward(indexPath.section, { $0.tableView?(tableView, commit: editingStyle, forRowAt: indexPath) })
        }
        
        func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
            return forward(indexPath.section, { $0.tableView?(tableView, canEditRowAt: indexPath) ?? false })
        }
        
        func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
            return forward(indexPath.section, { $0.tableView?(tableView, canMoveRowAt: indexPath) ?? false })
        }
        
        func tableView(_ tableView: UITableView, moveRowAt sourceIndexPath: IndexPath, to destinationIndexPath: IndexPath) {
            // this may require reworking to support moving rows across sections???
            
            forward(sourceIndexPath.section, { $0.tableView?(tableView, moveRowAt: sourceIndexPath, to: destinationIndexPath) })
        }
        
        // UTableViewDelegate forwarding
        
        func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
            forward(indexPath.section, { $0.tableView?(tableView, didSelectRowAt: indexPath) })
        }
        
        func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
            return forward(indexPath.section, { $0.tableView?(tableView, heightForRowAt: indexPath) ?? tableView.rowHeight })
        }
    }
    
    /// binds to a publisher of TableViewSectionBindings. Sectin changes will be tracked.
    /// - Parameter publisher: publisher of a RealmCollectionChange for an array of TableViewSectionBindings
    /// - Returns: a TableViewBinding for the indicated sections.
    public static func sections<P: Publisher>(_ publisher: P) -> TableViewBinding where P.Output == RealmCollectionChange<[TableViewSectionBinding]>, P.Failure == Never {
        return Sections(publisher)
    }
    
    /// binds to a array of TableViewSectionBindings.
    /// - Parameter sections: An array of TableViewSectionBindings.
    /// - Returns: a TableViewBinding for the indicated sections.
    public static func sections(_ sections: [TableViewSectionBinding]) -> TableViewBinding {
        return Sections(Just(.initial(sections)))
    }
    
    /// binds to a array of TableViewSectionBindings.
    /// - Parameter sections: An array of TableViewSectionBindings.
    /// - Returns: a TableViewBinding for the indicated sections.
    public static func sections(_ sections: TableViewSectionBinding...) -> TableViewBinding {
        return Sections(Just(.initial(sections)))
    }
}

