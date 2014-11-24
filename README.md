# DataStore

DataStore is a unit tested iOS & Mac OS X framework to handle multithreaded Core Data operations. It is a convenient wrapper around fetching, saving and reseting Core Data operations.

The API allows the developer to easily launch synchronous or asynchronous operations on either the main queue or the background queue. DataStore ensures that the contexts remain in sync removing this often erroneous and tedious task from the developer responsibilities.

## Requirements 

iOS 8.0+ or Mac OS X 10.10+

DataStore can be used with Swift and [Objective-C](https://developer.apple.com/library/ios/documentation/swift/conceptual/buildingcocoaapps/MixandMatch.html) projects.

## Installation

Follow the following steps to use the DataStore framework in your project:

1. Add DataStore as a git submodule by opening the Terminal, cd-ing into your top-level project directory, and copying/typing this line `git submodule add https://github.com/jad6/DataStore.git`
2. Open the DataStore folder, and drag `DataStore.xcodeproj` into the file navigator of your app project.
3. In the Xcode project navigator select `Build Settings` and for the `Header Search Path` key add the following value: **`$(CONFIGURATION_BUILD_DIR)`** to the existing array.
4. Then select the `Build Phases` tab and under `Target Dependencies` add the appropriate DataStore target for your platform. *Note:* If you do not see any DataStore targets please ensure you correctly did step 2.
5. Lastly, in the `General` tab add the appropriate `DataStore.framework` for your targeted platform under the `Linked Frameworks and Libraries` section.

## Usage

Once the framework is integrated with your app project, simply import DataStore as a module in any file you wish to use it in.

Swift: `import DataStore`

Objective-C: `@import DataStore;`

### Swift Note

When Xcode generates the subclasses for the `NSManagedObject`s in your model you **need** to include a line above the class declaration with the following format: `objc(<Class Name>)`.

This is due to the fact that Swift currently [does not have a much in terms of introspection](http://stackoverflow.com/a/24107909) and it will hopefully get fixed soon enough. Please have a look at the "[Swift Roughness](https://github.com/jad6/DataStore#swift-roughness)" section for more details.

### Singleton Object

A typical approach is to wrap a `DataStore` object in a singleton object to ensure you only refer to that single instance throughout your project. Below is an example class which does just that:

```Swift
import Foundation
import CoreData
import DataStore

class CoreDataManager {
    
    class var sharedManager: CoreDataManager {
        struct Singleton {
            static let instance = CoreDataManager()
        }
        return Singleton.instance
    }
    
    let dataStore: DataStore
    
    private init() {
        let directories = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, false)
        let storePath = directories.last?.stringByAppendingPathComponent("<#filenmae.sqlite3#>")
        assert(storePath != nil, "For an sqlite store you need a store path")
        
        let model = DataStore.modelForResource("<#Model Name#>", bundle: NSBundle.mainBundle())
        assert(model != nil, "Cannot create model")
        
        dataStore = DataStore(model: model!, storePath: storePath)
    }
}
```

### Synchronous Operations

It is easy to perform synchronous operations on the main queue and/or background queue using methods provided by the framework. 

#### Inserting on Background Queue

```Swift
let error: NSError?
let entityName = dataStore.entityNameForObjectClass(<#Managed Object Subclass#>, withClassPrefix: "<#Prefix#>")
dataStore.performBackgroundClosureWaitAndSave({ context in
    context.insertObjectWithEntityName(entityName) { object in
        let instance = object as <#Managed Object Subclass#>
        <#Code#>
    }
}, error: &error)
```

#### Fetching on Main Queue

```Swift
let entityName = dataStore.entityNameForObjectClass(<#Managed Object Subclass#>, withClassPrefix: "<#Prefix#>")
dataStore.performClosureAndWait() { context in
    let predicate = <#Your Predicate#>
    
    // Here we are fetching on the backgroundManagedObjectContext.
    let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, andSortDescriptors: <#Sort Descriptors#>, error: &error) as [<#Managed Object Subclass#>]
    
    // Do stuff on the background queue
}
```

### Asynchronous Operations

It is just as easy to perform asynchronous operations on the main queue and/or background queue using methods provided by the framework. When mixing asynchronous operations and certain methods caution should be used, please have a look at the "[A Word of Caution With Asynchronous Contexts](https://github.com/jad6/DataStore#a-word-of-caution-with-asynchronous-contexts)" section.

#### Insertion If Empty Fetch Result on Background Queue

```Swift
let entityName = dataStore.entityNameForObjectClass(<#Managed Object Subclass#>, withClassPrefix: "<#Prefix#>")

dataStore.performBackgroundClosureAndSave({ context in
    var error: NSError?
    context.findEntitiesWithEntityName(entityName,
        wherKey: "<#key#>",
        equalsValue: <#Value#>,
        error: &error) { insertedObject in
            let instance = object as <#Managed Object Subclass#>
            <#Code#>
    }
}, completion: { context, error in
    // This is called on the main queue when the save is complete.
})
```

#### Fetching All Entities on Background Queue

```Swift
let entityName = dataStore.entityNameForObjectClass(<#Managed Object Subclass#>, withClassPrefix: "<#Prefix#>")

dataStore.performBackgroundClosure() { context in
    var fetchError: NSError?
    let results = context.findAllForEntityWithEntityName(entityName, error: &fetchError) as <#Managed Object Subclass#>
    
    // Do any work asynchronously on the background queue with backgroundManagedObjectContext.
}
```

### A Word of Caution With Asynchronous Contexts

There are scenarios where methods provided by the framework (or ones you write yourself) when called in certain sequences may cause behaviours which you would not expect. Let's take a look at the code below:

```Swift
let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")

var group = dispatch_group_create()

dispatch_group_enter(group)
dataStore.performClosureAndSave({ context in
    var error: NSError?
    context.findEntitiesWithEntityName(entityName,
        wherKey: "firstName",
        equalsValue: "Jad",
        error: &error) { insertedObject in
            let person = insertedObject as? DSTPerson
            person?.firstName = "Jad"
            person?.lastName = "Osseiran"
    }
}, completion: { context, error in
    dispatch_group_leave(group)
})

dispatch_group_enter(group)
dataStore.performBackgroundClosureAndSave({ context in
    var error: NSError?
    context.findEntitiesWithEntityName(entityName,
        wherKey: "firstName",
        equalsValue: "Jad",
        error: &error) { insertedObject in
            let person = insertedObject as? DSTPerson
            person?.firstName = "Jad"
            person?.lastName = "Osseiran"
    }
}, completion: { context, error in
    dispatch_group_leave(group)
})

dispatch_group_notify(group, dispatch_get_main_queue()) {
    self.dataStore.performClosureAndWait() { context in
        let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
        
        var error: NSError?
        let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as [DSTPerson]
        
        // How many objects will be in results?
    }
}
```

Here there are two asynchronous calls made on the `dataStore` object: `performClosureAndSave` and `performBackgroundClosureAndSave`. These two calls happen asynchronously form one another and it is possible that in some occasions one context saves before the other context makes the fetch for key-value pair: `firstName`-`Jad`. This would give only one element in `results`, like what we would expect. However it is possible that the fetches happen at the same time (or thereabouts) and therefore the save of a context cannot happen before the fetch of the other. This would yield a duplication of `DSTPerson` "Jad Osseiran" but with different `ObjectID`s. **Not what you would expect**. 

This is because of the nature of `findEntitiesWithEntityName:whereKey:equalsValue:error` which looks for a matching managed object and creates one if not found. So we can end up with a double creation if we are not careful. 

To avoid such dilemmas please *try to avoid* saving the same data on different contexts asynchronously.

## Concurrency Approach

After exploring and attempting several approaches I settled on a notification based context syncing approach. This approach requires the use of three `NSManagedObjectContext`s:

1. The `writerManagedObjectContext` responsible for saving the synced up context master state. This context is directly connected to the persistent store coordinator and can be seen as the *parent context*.
2. The `mainManagedObjectContext` responsible for handling the operations on the main queue. It is the child of `writerManagedObjectContext`.
3. The `backgroundManagedObjectContext` responsible for handling the operations on the background queue. It is the child of `writerManagedObjectContext` and *"sibling"*" of `mainManagedObjectContext`.

The hierarchy between these contexts is as follows:

                  writerManagedObjectContext                    (parent)
                    /                 \
                   /                   \
    mainManagedObjectContext    backgroundManagedObjectContext  (children)
                          
The changes between children are kept in sync by the use of the `NSManagedObjectContextDidSaveNotification` which is observed when either of the children contexts perform a save operation. At this point the context which is not being saved calls `mergeChangesFromContextDidSaveNotification:` on its respectful queue to sync up with the changes brought by the save on its sibling context. The save then propagates up to the parent `writerManagedObjectContext` for the final master save.

Both of the children contexts are public in the API however the `writerManagedObjectContext` is private and is not to be accessed by users of the framework.

### Example

Let’s imagine we have two contexts: `C1` & `C2` and they are in states `A` & `B` respectively. There is a last private context handling the writing to disk, let’s call this one `C0`. `C0` also happens to be the parent context for both `C1` & `C2` (which can in turn be seen as siblings). Now let's imagine a save operation happens on `DataStore` using either `save:` or `saveAndWait:`.

We save `C1` which sends a `NSManagedObjectContextDidSaveNotification` and in the observer we merge changes by calling `mergeChangesFromContextDidSaveNotification:` on `C2`. Now we have `C1` which has state `A` saved and `C2` which has now merged with `C1` to reflect state `AB` but is **not** saved yet.

Next we save `C2` and it correctly propagates state `AB` up to the writer context `C0`. Because of the save notification triggered when saving `C2`, `C1` now also has state `AB` but is **not** saved.

Lastly the writer context `C0` saves and due to its nature it writes the state `AB` to disk concluding the procedure. 

The final state of the contexts and states is shown the table below:

|             | `C1` | `C2` | `C0` |
| :---------- | :---:| :---:| :--: |
| **State**   | `AB` | `AB` | `AB` |
| **Saved**   |  No  | Yes  | Yes  |
| **Changes** |  No  |  No  |  No  |

## Swift Roughness

This framework has been written in Swift. In hindsight I probably should have done it in Objective-C due to the youth of Swift. However, in the long run I am sure the issues below will be ironed out as the language matures. 

Below are the issues I ran into whilst developing this framework.

### Xcode Generated `NSManagedObject` Subclasses

When Xcode generates the subclasses for the `NSManagedObject`s in your model you **need** to include a line above the class declaration with the following format: `objc(<Class Name>)`.

**Note**: This will remove the namespacing that Swift provides by default. So maybe name your class with a prefix.

```Swift
import Foundation
import CoreData

// This has to be added in order for Core Data to be happy.
@objc(DSTPerson)
class DSTPerson: NSManagedObject {

    @NSManaged var dateOfBirth: NSDate
    @NSManaged var firstName: String
    @NSManaged var lastName: String
    @NSManaged var phones: NSSet

}
```
