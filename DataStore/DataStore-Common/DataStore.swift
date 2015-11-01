//
//  DataStore.swift
//  DataStore
//
//  Created by Jad Osseiran on 8/11/2014.
//  Copyright (c) 2015 Jad Osseiran. All rights reserved.
//
//  Redistribution and use in source and binary forms, with or without
//  modification, are permitted provided that the following conditions are met:
//
//  * Redistributions of source code must retain the above copyright notice, this
//  list of conditions and the following disclaimer.
//
//  * Redistributions in binary form must reproduce the above copyright notice,
//  this list of conditions and the following disclaimer in the documentation
//  and/or other materials provided with the distribution.
//
//  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
//  AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
//  IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE
//  DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR CONTRIBUTORS BE LIABLE
//  FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL
//  DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR
//  SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER
//  CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY,
//  OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE
//  OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

import CoreData

/**
 * Encapsulating class to allow the managing of Core Data operations, contexts,
 * stores and models.
 */
public class DataStore: NSObject {
            
    /// Closure type giving back a context.
    public typealias ContextClosure = (context: NSManagedObjectContext) -> Void
    /// Closure type giving back a context and an error.
    public typealias ContextSaveClosure = (context: NSManagedObjectContext, error: NSError?) -> Void
    /// Closure type giving back an error.
    public typealias SaveClosure = (error: NSError?) -> Void

    // MARK: Properties
    
    /// The persistent store type which is used by the data store.
    public let storeType: String
    /// The managed object model used by the data store.
    public let managedObjectModel: NSManagedObjectModel
    /// The persistent store coordinator used by the data store.
    public let persistentStoreCoordinator: NSPersistentStoreCoordinator
    /// The ubiquitous key used to identify the cloud store.
    public private(set) var cloudUbiquitousNameKey: String?
    
    /// Main context lined to the main queue.
    public private(set) var mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    /// Background context linked to a background queue.
    public private(set) var backgroundManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    /// Private writing context linked to a background queue responsible for 
    /// writig the state of the model to disk. This context is
    /// the parent of the sibling contexts mainManagedObjectContext &
    /// backgroundManagedObjectContext.
    private(set) var writerManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    
    // FIXME: Yuck... http://www.klundberg.com/blog/Swift-2-and-@available-properties/
    private var _mergePolicy: NSMergePolicy? {
        didSet {
            if #available(iOS 9, OSX 10.11, *) {
                // Set the default merge policy type
                let policy = mergePolicy != nil ? mergePolicy! : NSMergePolicy(mergeType: .MergeByPropertyObjectTrumpMergePolicyType)
                writerManagedObjectContext.mergePolicy = policy
                mainManagedObjectContext.mergePolicy = policy
                backgroundManagedObjectContext.mergePolicy = policy
            }
        }
    }
    /// If this merge policy is set then the Core Data constraints will use it to merge the uniqueness conflicts it comes accross.
    /// This is not set by default and a `NSMergeByPropertyObjectTrumpMergePolicy` type is used by default.
    @available(iOS 9, OSX 10.11, *)
    public var mergePolicy: NSMergePolicy? {
        get {
            return _mergePolicy
        }
        set {
            _mergePolicy = newValue
        }
    }
    
    /// Checks accross all contexts to see if there are changes.
    public var hasChanges: Bool {
        return self.writerManagedObjectContext.hasChanges ||
            self.mainManagedObjectContext.hasChanges ||
            self.backgroundManagedObjectContext.hasChanges
    }
    
    // MARK: Initialisers
    
    /**
     * Designated initialiser to set up the environment for Core Data. If the 
     * persistent store coordinator could not be added, the initialisation fails.
     * - throws: If a new store cannot be created an instance of NSError that describes the problem will be thrown.
     *
     * - parameter model: The model to use througout the application.
     * - parameter configuration: The name of a configuration in the receiver's managed object model that will be used by the new store. The configuration can be nil, in which case no other configurations are allowed.
     * - parameter storePath: The file location of the persistent store.
     * - parameter storeType: A string constant (such as! NSSQLiteStoreType) that specifies the store type.
     * - parameter options: A dictionary containing key-value pairs that specify whether the store should be read-only, and whether (for an XML store) the XML file should be validated against the DTD before it is read. This value may be nil.
     */
    public init(model: NSManagedObjectModel,
        configuration: String?,
        storePath: String?,
        storeType: String,
        options: [NSObject : AnyObject]?) throws {
            // Initialise the class' properties
            self.storeType = storeType
            self.managedObjectModel = model
            self.persistentStoreCoordinator = NSPersistentStoreCoordinator(managedObjectModel: model)

            super.init()

            // Convert the path to a URL.
            var storeURL: NSURL?
            if storePath != nil {
                storeURL = NSURL(fileURLWithPath: storePath!)
            }

            // Set the coordinator to the write context.
            self.writerManagedObjectContext.persistentStoreCoordinator = self.persistentStoreCoordinator
            // Set the writing object context to be the parent of the sibling contexts
            // mainManagedObjectContext & backgroundManagedObjectContext.
            self.mainManagedObjectContext.parentContext = self.writerManagedObjectContext
            self.backgroundManagedObjectContext.parentContext = self.writerManagedObjectContext
            
            // Register for Core Data notifications
            self.handleNotifications()

            // Add a persitent store from the given information.
            try self.persistentStoreCoordinator.addPersistentStoreWithType(storeType,
                configuration: configuration,
                URL: storeURL,
                options: options)
    }

    /**
     * Convenience initialiser which sets up a Core Data environment with
     * a SQLLite store type with a persistent store having no configurations and options
     * NSMigratePersistentStoresAutomaticallyOption & NSInferMappingModelAutomaticallyOption
     * enabled. If the persistent store coordinator could not be added, 
     * the initialisation fails.
     * - throws: If a new store cannot be created an instance of NSError that describes the problem will be thrown.
     *
     * - parameter model: The model to use througout the application.
     * - parameter storePath: The file location of the persistent store.
     */
    public convenience init!(model: NSManagedObjectModel, storePath: String?) throws {
        // Set default options.
        let options = [NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true]
        
        try self.init(model: model,
            configuration: nil,
            storePath: storePath,
            storeType: NSSQLiteStoreType,
            options: options)
    }
    
    /**
     Convenience initialiser which sets up a cloud Core Data environment with
     a SQLLite store type with a persistent store having no configurations and options
     NSMigratePersistentStoresAutomaticallyOption, NSInferMappingModelAutomaticallyOption
     & NSPersistentStoreUbiquitousContentNameKey enabled. If the persistent
     store coordinator could not be added, the initialisation fails.
     - throws: If a new store cannot be created an instance of NSError that describes the problem will be thrown.

     - parameter model: The model to use througout the application.
     - parameter cloudUbiquitousNameKey: Option to specify that a persistent store has a given name in ubiquity.
     - parameter storePath: The file location of the persistent store.
     */
    public convenience init!(model: NSManagedObjectModel,
        cloudUbiquitousNameKey: String,
        storePath: String?) throws {
            // Set cloud options.
            let options: [NSObject : AnyObject] = [NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreUbiquitousContentNameKey: cloudUbiquitousNameKey]

            try self.init(model: model,
                configuration: nil,
                storePath: storePath,
                storeType: NSSQLiteStoreType,
                options: options)
            
            self.cloudUbiquitousNameKey = cloudUbiquitousNameKey
    }
    
    /**
     * Deinitialisation to perform data stroe cleanup operations.
     */
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: Asynchronous Methods
    
    /**
     Method to save all contexts in the data store asynchronously. A callback is
     given at each context save.
     - note: At the end of the same all contexts will be reset.

     - parameter contextSave: A callback given at each context save.
     - parameter completion: A callback at the end of the save operation with error reporting.
     */
    public func save(onContextSave contextSave: ContextClosure?, completion: SaveClosure?) {
        saveContext(mainManagedObjectContext, onSave: contextSave) { [weak self] error in
            if error != nil || self == nil {
                var saveError = error
                if self == nil {
                    saveError = NSError.prematureDeallocationError
                }
                
                // Abort if there is an error with the main queue save.
                dispatch_async(dispatch_get_main_queue()) {
                    completion?(error: saveError)
                }
            } else {
                self!.saveContext(self!.backgroundManagedObjectContext, onSave: contextSave) { [weak self] error in
                    if error != nil || self == nil {
                        var saveError = error
                        if self == nil {
                            saveError = NSError.prematureDeallocationError
                        }

                        // Abort if there is an error with the background queue save.
                        dispatch_async(dispatch_get_main_queue()) {
                            completion?(error: saveError)
                        }
                    } else {
                        self!.saveContext(self!.writerManagedObjectContext, onSave: contextSave) { [weak self] error in
                            var saveError = error
                            if self == nil {
                                saveError = NSError.prematureDeallocationError
                            }

                            // Abort if there is an error with deallocating self prematurely.
                            dispatch_async(dispatch_get_main_queue()) {
                                // Reset the contexts as we are done with the change syncing
                                self?.resetContexts()

                                completion?(error: saveError)
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Method to save all contexts in the data store asynchronously.
     * - note: At the end of the same all contexts will be reset.
     *
     * - parameter completion: A callback at the end of the save operation with error reporting.
     */
    public func save(completion: SaveClosure?) {
        save(onContextSave: nil, completion: completion)
    }
    
    // MARK: Synchronous Methods
    
    /**
     * Method to save all contexts in the data store synchronously. A callback is
     * given at each context save. 
     * - note: At the end of the same all contexts will be reset.
     * - throws: An error if the save operations fail.
     *
     * - parameter contextSave: A callback given at each context save.
     */
    public func saveAndWait(onContextSave contextSave: ContextClosure?) throws {
        // Try saving the main context.
        try saveContextAndWait(mainManagedObjectContext, onSave: contextSave)
        // If we did not throw an error on the main context, try saving the background context.
        try saveContextAndWait(backgroundManagedObjectContext, onSave: contextSave)
        // If we did not throw an error on the background context, try saving the writer context.
        try saveContextAndWait(writerManagedObjectContext, onSave: contextSave)

        // Reset the contexts as we are done with the change syncing
        resetContexts()
    }
    
    /**
     * Method to save all contexts in the data store synchronously.
     * - note: At the end of the same all contexts will be reset.
     * - throws: An error if the save operations fail.
     */
    public func saveAndWait() throws {
        try saveAndWait(onContextSave: nil)
    }
    
    // MARK: Store Methods
    
    /**
     * Helper method to return the URLs (if there is one) of the persitent stores
     * managed by the data store's persistentStoreCoordinator.
     *
     * - complexity: O(n)
     * - returns: An array of NSURLs with the stores' URLs.
     */
    public func persistentStoresURLs() -> [NSURL] {
        // Insure the stores can be downcasted.
        let stores = persistentStoreCoordinator.persistentStores
        var storeURLs = [NSURL]()
        // For each stores add the URL if there is one.
        for store in stores {
            if let storeURL = store.URL {
                storeURLs.append(storeURL)
            }
        }
        return storeURLs
    }

    /**
     * Helper method to return the cloud persitent stores managed by the data
     * store's persistentStoreCoordinator.
     *
     * - complexity: O(n)
     * - returns: The cloud persitent stores.
     */
    public func cloudPersistentStores() -> [NSPersistentStore] {
        // Insure the stores can be downcasted.
        let stores = persistentStoreCoordinator.persistentStores
        var cloudStores = [NSPersistentStore]()
        // Look for the cloud stores.
        for store in stores {
            if store.options?[NSPersistentStoreUbiquitousContentNameKey] != nil {
                cloudStores.append(store)
            }
        }
        return cloudStores
    }

    /**
     * Helper method to reset all contexts.
     */
    public func resetContexts() {
        self.mainManagedObjectContext.reset()
        self.backgroundManagedObjectContext.reset()
        self.writerManagedObjectContext.reset()
    }
    
    // MARK: Private Methods
    
    /**
     * Asynchronous context saving helper method.
     *
     * - parameter context: The context to save.
     * - parameter contextSave: A callback given at each context save.
     * - parameter completion: A callback at the end of the save operation with error reporting.
     */
    private func saveContext(context: NSManagedObjectContext, onSave contextSave: ContextClosure?, completion: ((error: NSError?) -> Void)?) {
        context.performBlock() {
            var saveError: NSError?
            do {
                try context.save()
                // Give save callback for the context.
                contextSave?(context: context)
            } catch let error as NSError {
                saveError = error
            } catch {
                fatalError()
            }

            completion?(error: saveError)
        }
    }
    
    /**
     * Synchronous context saving helper method.
     * - throws: An error if the save operations fail.
     *
     * - parameter context: The context to save.
     * - parameter contextSave: A callback given at each context save.
     */
    private func saveContextAndWait(context: NSManagedObjectContext, onSave contextSave: ContextClosure?) throws {
        var caughtError: NSError?

        context.performBlockAndWait() {
            do {
                try context.save()
                // Give save callback for the context.
                contextSave?(context: context)
            } catch let error as NSError {
                caughtError = error
            } catch {
                fatalError()
            }
        }

        if let error = caughtError {
            throw error
        }
    }
}
