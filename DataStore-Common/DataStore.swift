//
//  DataStore.swift
//  DataStore
//
//  Created by Jad Osseiran on 8/11/2014.
//  Copyright (c) 2014 Jad Osseiran. All rights reserved.
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

    // MARK: - Properties
    
    /// The file location of the persistent store.
    public private(set) var storePath: String?
    /// The persistent store type which is used by the data store.
    public let storeType: String
    /// The managed object model used by the data store.
    public let managedObjectModel: NSManagedObjectModel
    /// The persistent store coordinator used by the data store.
    public let persistentStoreCoordinator: NSPersistentStoreCoordinator
    
    /// Main context lined to the main queue.
    public private(set) var mainManagedObjectContext = NSManagedObjectContext(concurrencyType: .MainQueueConcurrencyType)
    /// Background context linked to a background queue.
    public private(set) var backgroundManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    /// Private writing context linked to a background queue responsible for 
    /// writig the state of the model to disk. This context is
    /// the parent of the sibling contexts mainManagedObjectContext &
    /// backgroundManagedObjectContext.
    private var writerManagedObjectContext = NSManagedObjectContext(concurrencyType: .PrivateQueueConcurrencyType)
    
    // MARK: - Initialisers

    /**
     * Designated initialiser to set up the environment for Core Data. If the 
     * persistent store coordinator could not be added, the initialisation fails.
     *
     * :param: model The model to use througout the application.
     * :param: configuration The name of a configuration in the receiver's managed object model that will be used by the new store. The configuration can be nil, in which case no other configurations are allowed.
     * :param: storePath The file location of the persistent store.
     * :param: storeType A string constant (such as NSSQLiteStoreType) that specifies the store type.
     * :param: options A dictionary containing key-value pairs that specify whether the store should be read-only, and whether (for an XML store) the XML file should be validated against the DTD before it is read. This value may be nil.
     * :param: error If a new store cannot be created an instance of NSError that describes the problem will populate this parameter.
     */
    public init!(model: NSManagedObjectModel,
        configuration: String?,
        storePath: String?,
        storeType: String,
        options: [NSObject : AnyObject]?,
        error: NSErrorPointer) {
            // Create a persistent store coordinator from wih the given model.
            let coordinator = NSPersistentStoreCoordinator(managedObjectModel: model)
            
            var storeURL: NSURL?
            if storePath != nil {
                storeURL = NSURL(fileURLWithPath: storePath!)
            }
            
            // Add a persitent store from the given information.
            let storeAdded = coordinator.addPersistentStoreWithType(storeType,
                configuration: configuration,
                URL: storeURL,
                options: options,
                error: error)
            
            // Initialise the class properties
            self.storePath = storePath
            self.storeType = storeType
            self.managedObjectModel = model
            self.persistentStoreCoordinator = coordinator
            
            super.init()
            
            // Fail initialisation if the persitent store could not be added.
            if storeAdded == false {
                return nil
            }
            
            // Register for the sibling contexts save notifications on their 
            // respective queues.
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleMainContextSaveNotification:", name:
                NSManagedObjectContextDidSaveNotification, object: self.mainManagedObjectContext)
            NSNotificationCenter.defaultCenter().addObserver(self, selector: "handleBackgroundContextSaveNotification:", name:
                NSManagedObjectContextDidSaveNotification, object: self.backgroundManagedObjectContext)
            
            // Set the coordinator to the write context.
            self.writerManagedObjectContext.persistentStoreCoordinator = coordinator
            // Set the writing object context to be the parent of the sibling contexts
            // mainManagedObjectContext & backgroundManagedObjectContext.
            self.mainManagedObjectContext.parentContext = self.writerManagedObjectContext
            self.backgroundManagedObjectContext.parentContext = self.writerManagedObjectContext
    }
    
    /**
     * Convenience initialiser which sets up a Core Data environment with
     * a SQLLite store type with a persistent store having no configurations and options
     * NSMigratePersistentStoresAutomaticallyOption & NSInferMappingModelAutomaticallyOption
     * enabled. If the persistent store coordinator could not be added, 
     * the initialisation fails.
     *
     * :param: model The model to use througout the application.
     * :param: storePath The file location of the persistent store.
     */
    public convenience init!(model: NSManagedObjectModel, storePath: String?) {
        // Set default options.
        let options = [NSMigratePersistentStoresAutomaticallyOption: true, NSInferMappingModelAutomaticallyOption: true]
        // Declare possible error for initialisation.
        var error: NSError?
        
        self.init(model: model,
            configuration: nil,
            storePath: storePath,
            storeType: NSSQLiteStoreType,
            options: options,
            error: &error)
        
        // Handle any possible errors.
        error?.handle()
    }
    
    /**
     * Deinitialisation to perform data stroe cleanup operations.
     */
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    // MARK: - Asynchronous Methods
    
    /**
     * Method to save all contexts in the data store asynchronously. A callback is 
     * given at each context save.
     *
     * :param: contextSave A callback given at each context save.
     * :param: completion A callback at the end of the save operation with error reporting.
     */
    public func save(onContextSave contextSave: ContextClosure?, completion: SaveClosure?) {
        saveContext(mainManagedObjectContext, onSave: contextSave) { error in
            if error != nil && completion != nil {
                // Abort if there is an error with the main queue save.
                dispatch_async(dispatch_get_main_queue()) {
                    completion!(error: error)
                }
            } else {
                self.saveContext(self.backgroundManagedObjectContext, onSave: contextSave) { error in
                    if error != nil && completion != nil {
                        // Abort if there is an error with the background queue save.
                        dispatch_async(dispatch_get_main_queue()) {
                            completion!(error: error)
                        }
                    } else {
                        self.saveContext(self.writerManagedObjectContext, onSave: contextSave) { error in
                            if completion != nil {
                                dispatch_async(dispatch_get_main_queue()) {
                                    completion!(error: error)
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    
    /**
     * Method to save all contexts in the data store asynchronously.
     *
     * :param: completion A callback at the end of the save operation with error reporting.
     */
    public func save(completion: SaveClosure?) {
        save(onContextSave: nil, completion: completion)
    }
    
    // MARK: - Synchronous Methods
    
    /**
     * Method to save all contexts in the data store synchronously. A callback is
     * given at each context save.
     *
     * :param: contextSave A callback given at each context save.
     * :param: error An error to be populated if the save operations fail.
     *
     * :returns: true if the save was successful.
     */
    public func saveAndWait(onContextSave contextSave: ContextClosure?, error: NSErrorPointer) -> Bool {
        if saveContextAndWait(mainManagedObjectContext,
            onSave: contextSave,
            error: error) == false {
                // Abort if there is an error with the main queue save.
                return false
        } else {
            if saveContextAndWait(backgroundManagedObjectContext,
                onSave: contextSave,
                error: error) == false {
                    // Abort if there is an error with the background queue save.
                    return false
            } else {
                if saveContextAndWait(writerManagedObjectContext,
                    onSave: contextSave,
                    error: error) == false {
                        // Abort if there is an error with the writer queue save.
                        return false
                }
            }
        }
        
        return true
    }
    
    /**
     * Method to save all contexts in the data store synchronously.
     *
     * :param: error An error to be populated if the save operations fail.
     *
     * :returns: true if the save was successful.
     */
    public func saveAndWait(error: NSErrorPointer) -> Bool {
        let saveSuccessful = saveAndWait(onContextSave: nil, error: error)
        
        return saveSuccessful
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the 
     * persistent stores as well as reseting all managed object contexts.
     *
     * :param: error The error which is populated if an error is encountered in the process.
     *
     * :returns: true if the process is successful.
     */
    public func reset(error: NSErrorPointer) -> Bool {
        var resetSuccess = false
        
        // Reset all contexts.
        writerManagedObjectContext.reset()
        mainManagedObjectContext.reset()
        backgroundManagedObjectContext.reset()

        // Make sure to perform the reset on closures to avoid deadlocks.
        writerManagedObjectContext.performBlockAndWait() {
            self.persistentStoreCoordinator.performBlockAndWait() {
                // Retrieve the stores which were coordinated.
                if let stores = self.persistentStoreCoordinator.persistentStores as? [NSPersistentStore] {
                    
                    let fileManager = NSFileManager.defaultManager()
                    for store in stores {
                        // Remove each persistent stores.
                        if self.persistentStoreCoordinator.removePersistentStore(store, error: error) == false {
                            resetSuccess = false
                            return
                        }
                        
                        // Remove the files if they exist.
                        if let storeURL = store.URL {
                            if let storePath = storeURL.path {
                                if fileManager.fileExistsAtPath(storePath) {
                                    // Remove the file where the store used to live.
                                    fileManager.removeItemAtURL(storeURL, error: error)
                                }
                            }
                        }
                        
                        // Fail if there is an error.
                        if error != nil {
                            resetSuccess = false
                            return
                        }
                    }
                    
                    for store in stores {
                        // create new fresh persistent stores.
                        let addSuccess = self.persistentStoreCoordinator.addPersistentStoreWithType(store.type, configuration: store.configurationName, URL: store.URL, options: store.options, error: error)
                        if addSuccess == false {
                            resetSuccess = false
                            return
                        }
                    }
                }
            }
        }
        
        return resetSuccess
    }
    
    // MARK: - Notifications
    
    /**
     * Notification method to handle logic once the main context has saved.
     *
     * :param: notification The notification object posted when mainManagedObjectContext was saved.
     */
    func handleMainContextSaveNotification(notification: NSNotification) {
        if let context = notification.object as? NSManagedObjectContext {
            // Merge the changes for the backgroundManagedObjectContext asynchronously.
            backgroundManagedObjectContext.performBlock() {
                self.backgroundManagedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }
    
    /**
     * Notification method to handle logic once the bacground context has saved.
     *
     * :param: notification The notification object posted when backgroundManagedObjectContext was saved.
     */
    func handleBackgroundContextSaveNotification(notification: NSNotification) {
        if let context = notification.object as? NSManagedObjectContext {
            // Merge the changes for the mainManagedObjectContext asynchronously.
            mainManagedObjectContext.performBlock() {
                self.mainManagedObjectContext.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
    }
    
    // MARK: - Private Methods
    
    /**
     * Asynchronous context saving helper method.
     *
     * :param: context The context to save.
     * :param: contextSave A callback given at each context save.
     * :param: completion A callback at the end of the save operation with error reporting.
     */
    private func saveContext(context: NSManagedObjectContext, onSave contextSave: ContextClosure?, completion: ((error: NSError?) -> Void)?) {
        context.performBlock() {
            var error: NSError?
            context.save(&error)
            
            if error != nil {
                // Give save callback for the context.
                contextSave?(context: context)
            }
            
            completion?(error: error)
        }
    }
    
    /**
     * Synchronous context saving helper method.
     *
     * :param: context The context to save.
     * :param: contextSave A callback given at each context save.
     * :param: error An error to be populated if the save operations fail.
     *
     * :returns: true if the save was successful.
     */
    private func saveContextAndWait(context: NSManagedObjectContext, onSave contextSave: ContextClosure?, error: NSErrorPointer) -> Bool {
        var success = true
        context.performBlockAndWait() {
            success = context.save(error)
        }
        
        if error != nil && success {
            // Give save callback for the context.
            contextSave?(context: context)
        }
        
        return success
    }
}
