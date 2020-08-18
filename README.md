# RealmCombineMVVM
An example project showing how you can use realm and Combine to create a reactive MVVM application.

## Model Support

In this example Models are stored in Realm. One of Realms great features is that you can subscribe to change to individual objects or entire queries. In addition to having it's own
native observation system is provides `Combine` `Publishers` that we use. Queries have queries that return the entire result set as it changes or a changeset that can be used to
animate updates. We use the latter, `changeSetPublisher`. Additionally, we have added an extension to `Object` that allows you to observe a single property, `.propertyValuePublisher()`.
This is very handy when propagating changes from your Model to your ViewModel.

## ViewModel Support

Ideally your ViewModel is primarily a mapping layer, transforming data and changes from your Models into a clean representation of what your Views will display.
In addition to the `propertyValuePublisher` discussed above, the `ObservableArray` makes this job much easier. 

The `ObservableArray` performs a couple roles. First, it gives you an easy way to map your Models into observable ViewModel Items. It then publishes the changes for you
so they can be easily bound to  `TableViewSectionBinding.items`. Additinally, the current array of mapped items is always available and there is a `Publisher` that publishes
the current value of the array (instead of the changes.) If your ViewModel Item conforms to `ViewModelItem`, then `ViewModelItemArray` can create your ViewModel Items from
the Models without any explicit mapping code. Realm's `Result` has an extension that will return an `ObservableArray`, `.asItemArray()`. In the end it allows to create code 
like the following:

    class PeopleViewModel {
        let items: AnyObservableArray<Item>
        
        init() {
            let realm = try! Realm()

            self.items = realm.objects(Person.self)
                .sorted(by: ["firstName", "lastName"])
                .asObservableArray()
        }

        class Item: ViewModelItem {
            let id: String
            let name: String
                
            required init(_ person: Person) {
                id = person.id
                name = "\(person.firstName) \(person.lastName)"
            }
        }
    }
    
`items` can be easily bound to a `TableViewSectionBinding` which will track changes and perform them interactively. Here we are creating an `ObservableArray` bound to 

### Updating ViewModel State

While most Data Binding involves pushing data from your View Model into your view, there are times when the ViewModel needs state from the UI. On the ViewModel side, you will usually want to use a `CurrentValueSubject`. This gives you access to the current value as well as allowing you to subscribe to changes. In your view you can simply update the values using the `.value` on the `CurrentValueSubject` or use data binding support for updating values.

### Validation

When state is coming into your view model you may need to have some kind of validation code. This may be to let View know when it is safe to commit changes or other state and validation information. This can be accomplished by using `CombineLatest` and `.map` to produce output values, as in the following:

        let firstName = CurrentValueSubject<String, Never>("")
        let lastName = CurrentValueSubject<String, Never>("")

        lazy var canAddPerson = Publishers.CombineLatest(self.firstName, self.lastName).map({ !$0.0.isEmpty && !$0.1.isEmpty }).eraseToAnyPublisher()
        
Note that while validation libraries exist, they tend to push validation out to the View layer which violates the basic principle of MVVM (business logic shouldn't be embedded in the View.) 
Generally speaking, validation logic should be handled in the ViewModel (using Combine in our case) and presented in the View.

## Data Binding Support

In order to make data binding from the ViewModel to the View cleaner and simpler a data binding operator has been introduced: `*=` (pronounced "binds to"). The left hand side
of the bind operator is receiving data from the right hand side. Generally speaking, it allows binding Publishers to UIKit values, although there is additional support for UITableView 
(See Table View Binding) as well as binding values back to the ViewModel.

The easiest way to understand what is happening is to start with how data binding with Combine might be done using existing API's. You might use the following to bind first and last
name Publishers in your ViewModel to UILabel's text property:

        @IBOutlet weak var firstName: UILabel!
        @IBOutlet weak var lastName: UILabel!
        
                    ...

        var bindings = Set<AnyCancellable>()
    
        func bind() {
            viewModel.firstName.sink(receiveValue: { self.firstName.text = $0 }).store(in: &bindings)
            viewModel.lastName.sink(receiveValue: { self.lastName.text = $0 }).store(in: &bindings)
        }

(Note: yes we could use `assign` instead of  `sink`, but it's not much more readable and doesn't handle null coercion well.) Using our binding syntax, we would have the following:

        var bindings: BindingGroup?

        func bind() {
            bindings = BindingGroup {
                firstName.textBinding *= viewModel.firstName
                lastName.textBinding *= viewModel.lastName
            }
        }

This is accomplished with a few small components. The first is the `BindingGroup`. It is essentially a wrapper around `Set<AnyCancellable>` with the concept of a current
"scope". The `BindingGroup` constructor sets the current binding group while the block passed to it is running and restores it after the call completes. (This is essentially a global
vartiable.) This allows us to capture sinks without having any explicily coded. 

The second component is the `Binding`. This is a very simple helper class that holds an object and writable key path. In our example `textBinding` is a `Binding` instance in an
extension to `UILabel`. These need to be defined for View properties you want to bind to.

The third is the binding operator, `*=`. There are couple flavors of this operator but they do essentially the same thing:

1. create a sink updating the property via the key path whenever the value changes

2. add the sink to the current `BindingGroup`

That's about all there is to it! Well, there are some special versions of the bind operator to support UITableViews and we also have some support for binding values back to the
ViewModel.

### Publishing data to the view model (Handling Inputs)

Inputs for ViewModels will be presented as some kind of `Subject`, which will often be a `CurrentValueSubject`. The View may explicitly update the value using `.send(value)`
To make this more declarative, bindings may be set-up for this reverse relationship as well. This has been done for `UITextField`s, using `TextFieldBinding`.

`TextFieldBinding` creates a delegate for a `UITextField` that can update a `Subject` as the user types. If a value is defined in the ViewModel as:

    let firstName = CurrentValueSubject<String, Never>("")
    
The View layer can bind to it using the following:

    self.firstNameLabel *= TextFieldBinding.subject(viewModel.firstName).nextField(self.lastNameLabel)
    
Additionally, we are telling the `TextFieldBinding` to use `self.lastNameLabel` as the "next field" using `TextFieldBinding`'s Composable Delegate support, see below.

## Composable Delegates

Composable delegates are a pattern that allows `NSObject`-based delegates to be defined as a series of fluent-style declarations. This is achieved by creating a "chain" of delegates that
act together as a composite object. The `ComposableDelegate<Delegate>` base class is the framework you can use to get started with this, it has an optional 'nextDelegate' variable that
will receive any messages that the object is not able to process itself. Composable Delegates are used for `TableViewBinding`  and `TextFieldBinding` in this example app.

A `TableViewSectionBinding` might be defined using the following:

    let delegate = TextFieldSectionBinding
        .items(self.viewModel.items)
        .headerTitle("People")
        .automaticRowHeight()
        .didSelectRow(self.didSelectRow)
        
This would create the following chain of delegates (note they are linked in the opposite order you see in code):

    TableViewSectionBinding.DidSelectRow (-tableView:didSelectRowAt:)
        nextDelegate: TableViewSectionBinding.RowHeight (-tableView:heightForRowAt:)
            nextDelegate:  TableViewSectionBinding.HeaderTitle (-tableView:titleForHeaderInSection:)
                nextDelegate: TableViewSectionBinding.Items (-tableView:numberOfRowsInSection:, -tableView:cellForRowAtIndexPath:)

## Table View Binding

The `TableViewBinding` and `TableViewSectionBinding` classes allow you to build a `UITableViewDataSource` and `UITableViewDelegate` using a fluent syntax. 
Additionally, there are bindings to `Combine`  `Publisher`s that allow changes to be dynamically updated. These bindings are designed specifically to work with Realm's 
change notifications system which posts inserts, deletes and changes.

The methods below handle the most common DataSource and Delegate methods but there are many mode that haven't been implemented. Adding new Bindings should be pretty easy
using the existing code as a guide. `TableViewBinding.default()` is your ultimate escape hatch -- it receives all delegate calls that aren't handled by the TableViewBinding, typically
could bind this to `self` and implement methods the conventional way.

### TableViewSectionBinding

`TableViewSectionBinding` builds a delegate for handling a single section. It may also be used directly as the data source/delegate if you have a single section table. The following 
methods allow you to define a section's behaviors:

- `items` - items is responsible for presnting the cells in the section. It can accept a  `Publisher` or an array of items. For a `Publisher` it should be publishing `RealmCollectionChange<[Element>]` events where `Element` is your ViewModel item. If the `Element` conforms to `BindableViewModelItem` it will be able to figure out the view (`UITableCell` descendent) for you, otherwise you can pass a method in to return the cell. You may also pass an arry of static `UITableViewCell`'s and those will be presented in
    the section.

- `headerTitle` and `footerTitle` - Defines the head or footer title for standard header cells. Pass nil to supress the display of the header or footer.

- `didSelectRow` - Pass a block to be executed whenever a row is selected

- `cellHeight`, `automaticCellHeight` - Pass a block to determine cell height, a constant value or use `automaticCellHeight` to use autolayout to determine the height.

### TableViewBinding

`TableViewBinding` is responsible for delegating calls to `TableViewSectionBinding`s for each section and handling any non-section related delegate methods. It can accept a `Publisher`
that publishes changes events which allows it to handle section insertion and deletion. (Note there is not much support for creating these `Publishers` currently.) You may also pass an array
of `TableViewSectionBinding`s which is expected to be the c ommon case.

 - `sections` - Receives either a `Publisher` or an array of `TableViewSectionBinding`s
 
 - `default` - Receives an `NSObject` that receives any delegate calls not handled by the rest of the system. This can be a convenient way to implement methods not covered by the
 TableViewBinding system.

### Binding operator *= for Table Views

TableViews have special versions of the "bind to" operator (`*=`) that handle the aditional book keeping required to wire up a table view delegate. These methods do the following:

1. sets the `tableView` property on the `TableViewBinding`
2. sets the `dataSource` and `delegate` properrties on the `UITableView` (pointing to the `TableViewBinding` object)
3. adds the `TableViewBinding` to the `BindingGroup`. This handles situations where the object is created in scope but would be dealloced because `dataSource` and `delehate`
are both weak bindings.

The right side of the bind operator may be the following types:

  - `TableViewSectionBinding` - Do all the actions listed above, binding to the cells for this view model
  - `ViewModelItemArray<Element>` - Bind to an array of items matching `Element`
 - `Publisher` (for a single section) - Bind to either a publisher of `RealmCollectionChange<[BindableViewModelItem]>` or `RealmCollectionChange<[UITableViewCell]>` (static)
 - `Publisher` (for multipel sections) - Bind to a publisher of `RealmCollectionChange<[TableViewSectionBinding]>` 
 - `Publisher` (for multiple sections) - Bind to `[TableViewSectionBinding]` (static)
