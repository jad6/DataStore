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
    
    /**
     * Convenient notifications struct containing the names and keys used 
     * throughout the DataStore.
     */
    public struct Notifications {
        /// Notification sent when one of the sibling contexts saves. The
        /// notification object is the DataStore object and the userInfo contains:
        ///     - DSSaveContextKey: the context which has been saved.
        ///     - DSMergedContextKey: the context which has been merged.
        public static let contextSavedAndMerge = "DSContextSavedAndMerge"
        /// Notification sent after a save when the stores are about to be
        /// swapped and there are changes on the context(s). The notification
        /// object is the DataStore object and the userInfo contains:
        ///     - DSPersistentStoreCoordinatorKey: The persistent store who's stores are swapped.
        ///     - DSErrorKey (optional): If there was an error in the save this key-value will be populated with it.
        public static let changesSavedFromTemporaryStore = "DSChangesSavedFromTemporaryStore"
        
        /**
         * The keys used for the notifications userInfo.
         */
        public struct Keys {
            /// The error key which will be included when errors are found.
            public static let error = "DSErrorKey"
            /// The persistent store coordinator attached to the notification.
            public static let persistentStoreCoordinator = "DSPersistentStoreCoordinatorKey"
            /// The context which has been saved.
            public static let saveContext = "DSSaveContextKey"
            /// The context which has been merged.
            public static let mergedContext = "DSMergedContextKey"
        }
    }
    
    /// Closure type giving back a context.
    public typealias ContextClosure = (context: NSManagedObjectContext) -> Void
    /// Closure type giving back a context and an error.
    public typealias ContextSaveClosure = (context: NSManagedObjectContext, error: NSError?) -> Void
    /// Closure type giving back an error.
    public typealias SaveClosure = (error: NSError?) -> Void

    // MARK: - Properties
    
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
    
    /// Checks accross all contexts to see if there are changes.
    public var hasChanges: Bool {
        return self.writerManagedObjectContext.hasChanges ||
            self.mainManagedObjectContext.hasChanges ||
            self.backgroundManagedObjectContext.hasChanges
    }
    
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
            if self.persistentStoreCoordinator.addPersistentStoreWithType(storeType,
                configuration: configuration,
                URL: storeURL,
                options: options,
                error: error) == nil {
                    // Fail initialisation if the persitent store could not be added.
                    return nil
            }
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
        let options = [NSMigratePersistentStoresAutomaticallyOption: true,
            NSInferMappingModelAutomaticallyOption: true]
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
     * Convenience initialiser which sets up a cloud Core Data environment with
     * a SQLLite store type with a persistent store having no configurations and options
     * NSMigratePersistentStoresAutomaticallyOption, NSInferMappingModelAutomaticallyOption
     * & NSPersistentStoreUbiquitousContentNameKey enabled. If the persistent
     * store coordinator could not be added, the initialisation fails.
     *
     * :param: model The model to use througout the application.
     * :param: storePath The file location of the persistent store.
     */
    public convenience init!(model: NSManagedObjectModel,
        cloudUbiquitousNameKey: String,
        storePath: String?) {
            // Set cloud options.
            let options = [NSMigratePersistentStoresAutomaticallyOption: true,
                NSInferMappingModelAutomaticallyOption: true,
                NSPersistentStoreUbiquitousContentNameKey: cloudUbiquitousNameKey]
            // Declare possible error for initialisation.
            var error: NSError?
            
            self.init(model: model,
                configuration: nil,
                storePath: storePath,
                storeType: NSSQLiteStoreType,
                options: options,
                error: &error)
            
            self.cloudUbiquitousNameKey = cloudUbiquitousNameKey
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
    
    // MARK: - Store Methods
    
    /**
     * Helper method to return the URLs (if there is one) of the persitent stores
     * managed by the data store's persistentStoreCoordinator.
     *
     * O(n)
     *
     * :returns: An array of NSURLs with the stores' URLs.
     */
    public func persistentStoresURLs() -> [NSURL] {
        // Insure the stores can be downcasted.
        if let stores = persistentStoreCoordinator.persistentStores as? [NSPersistentStore] {
            var storeURLs = [NSURL]()
            // For each stores add the URL if there is one.
            for store in stores {
                if let storeURL = store.URL {
                    storeURLs.append(storeURL)
                }
            }
            return storeURLs
        }
        
        // Return an empty array on failure.
        return [NSURL]()
    }
    
    /**
     * Helper method to return the cloud persitent stores managed by the data
     * store's persistentStoreCoordinator.
     *
     * O(n)
     *
     * :returns: The cloud persitent stores.
     */
    public func cloudPersistentStores() -> [NSPersistentStore] {
        // Insure the stores can be downcasted.
        if let stores = persistentStoreCoordinator.persistentStores as? [NSPersistentStore] {
            var cloudStores = [NSPersistentStore]()
            // Look for the cloud stores.
            for store in stores {
                if store.options?[NSPersistentStoreUbiquitousContentNameKey] != nil {
                    cloudStores.append(store)
                }
            }
            return cloudStores
        }
        
        // Return an empty array on failure.
        return [NSPersistentStore]()
    }
    
    /**
     * Helper method to reset all contexts.
     */
    public func resetContexts() {
        self.mainManagedObjectContext.reset()
        self.backgroundManagedObjectContext.reset()
        self.writerManagedObjectContext.reset()
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the 
     * persistent stores as well as reseting all managed object contexts.
     *
     * O(n)
     *
     * :param: error The error which is populated if an error is encountered in the process.
     *
     * :returns: true if the process is successful.
     */
    public func reset(error: NSErrorPointer) -> Bool {
        var resetSuccess = false
        
        // Reset all contexts.
        self.resetContexts()

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
     * Helper method to handle all the notification registrations and/or handlings.
     */
    private func handleNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        
        // Register a selector to handle this notification.
        notificationCenter.addObserver(self, selector: "handlePersistentStoresWillChangeNotification:", name: NSPersistentStoreCoordinatorStoresWillChangeNotification, object: persistentStoreCoordinator)
        
        // Register a selector for the notification in the case Core Data posts
        // content changes from iCloud.
        notificationCenter.addObserver(self, selector: "handleImportChangesNotification:", name:
            NSPersistentStoreDidImportUbiquitousContentChangesNotification, object: persistentStoreCoordinator)

        // Register for the sibling contexts save notifications on their
        // respective queues.
        notificationCenter.addObserver(self, selector: "handleMainContextSaveNotification:", name:
            NSManagedObjectContextDidSaveNotification, object: mainManagedObjectContext)
        notificationCenter.addObserver(self, selector: "handleBackgroundContextSaveNotification:", name:
            NSManagedObjectContextDidSaveNotification, object: backgroundManagedObjectContext)
    }
    
    /**
     * Notification method to handle logic just before stores swaping.
     *
     * :param: notification The notification object posted before the stores swap.
     */
    func handlePersistentStoresWillChangeNotification(notification: NSNotification) {
        var transitionType: NSPersistentStoreUbiquitousTransitionType?
        
        // Perform operations on the parent (root) context.
        writerManagedObjectContext.performBlock {
            if self.hasChanges {
                // If there are changes on the temporary contexts before the 
                // store swap then save them.
                var error: NSError?
                self.saveAndWait(&error)
                
                // Create the user info dictionary with the error if it occured.
                var userInfo: [String: AnyObject] = [Notifications.Keys.persistentStoreCoordinator: self.persistentStoreCoordinator]
                if error != nil {
                    userInfo = [Notifications.Keys.error: error!]
                }
                // Post the save temporary store notification.
                NSNotificationCenter.defaultCenter().postNotificationName(Notifications.changesSavedFromTemporaryStore, object: self, userInfo: userInfo)
                
                // On a transition Core Data gives the app only one chance to save;
                // it won’t post another NSPersistentStoreCoordinatorStoresWillChangeNotification
                // notification. Therefore reset the contexts after a save.
                if transitionType != nil {
                    // TODO: Test that this occurs on transtions, not initial set-up.
                    self.resetContexts()
                }
            } else {
                // Reset the managed object contexts as the data they hold is
                // now invalid due to the store swap.
                self.resetContexts()
            }
        }
    }
    
    /**
     * Notification method to handle logic for cloud store imports.
     *
     * :param: notification The notification object posted when data was imported.
     */
    func handleImportChangesNotification(notification: NSNotification) {
        // Inline closure to merge a context.
        let mergeContext = { (context: NSManagedObjectContext) -> Void in
            context.performBlock() {
                context.mergeChangesFromContextDidSaveNotification(notification)
            }
        }
        // Merge all contexts.
        mergeContext(writerManagedObjectContext)
        mergeContext(mainManagedObjectContext)
        mergeContext(backgroundManagedObjectContext)
    }
    
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
                
                // Send the save and merge notification.
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().postNotificationName(Notifications.contextSavedAndMerge, object: self, userInfo: [Notifications.Keys.mergedContext: self.backgroundManagedObjectContext, Notifications.Keys.saveContext: self.mainManagedObjectContext])
                }
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
                
                // Send the save and merge notification.
                dispatch_async(dispatch_get_main_queue()) {
                    NSNotificationCenter.defaultCenter().postNotificationName(Notifications.contextSavedAndMerge, object: self, userInfo: [Notifications.Keys.mergedContext: self.mainManagedObjectContext, Notifications.Keys.saveContext: self.backgroundManagedObjectContext])
                }
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
