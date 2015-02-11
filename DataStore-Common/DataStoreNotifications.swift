//
//  DataStoreNotifications.swift
//  DataStore
//
//  Created by Jad Osseiran on 29/11/2014.
//  Copyright (c) 2014 Jad Osseiran. All rights reserved.
//

import Foundation
import CoreData

public extension DataStore {
    
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
        
        public static let storeDidMoveToLocalFileSystemDirectory = "storeDidMoveToLocalFileSystemDirectory"
        public static let storeDidMoveToCloudFileSystemDirectory = "DSstoreDidMoveToCloudFileSystemDirectory"
        
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
            
            public static let directoryPath = "DSDirectoryPathKey"
        }
    }
    
    /**
     * Helper method to handle all the notification registrations and/or handlings.
     */
    func handleNotifications() {
        let notificationCenter = NSNotificationCenter.defaultCenter()
        
        // Register a selector to handle this notification.
        notificationCenter.addObserver(self, selector: "handlePersistentStoresDidChangeNotification:", name: NSPersistentStoreCoordinatorStoresDidChangeNotification, object: persistentStoreCoordinator)
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
                // Reset the managed object contexts as! the data they hold is
                // now invalid due to the store swap.
                self.resetContexts()
            }
        }
    }
    
    func handlePersistentStoresDidChangeNotification(notification: NSNotification) {
        if let coordinator = notification.object as? NSPersistentStoreCoordinator {
            if let stores = coordinator.persistentStores as? [NSPersistentStore] {
                for store in stores {
                    var error: NSError?
                    
                    var userInfo: [NSObject: AnyObject]?

                    // Move the store to the right directory.
                    if store.options?[NSPersistentStoreUbiquitousContentNameKey] != nil {
                        placeStoreInCloudDirectory(store, options: store.options, error: &error)
                        
                        if error != nil {
                            userInfo = [Notifications.Keys.error: error!]
                        }
                        
                        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.storeDidMoveToCloudFileSystemDirectory, object: store, userInfo: userInfo)
                    } else {
                        placeStoreInLocalDirectory(store, options: store.options, error: &error)
                        
                        if error != nil {
                            userInfo = [Notifications.Keys.error: error!]
                        }
                        
                        NSNotificationCenter.defaultCenter().postNotificationName(Notifications.storeDidMoveToLocalFileSystemDirectory, object: store, userInfo: userInfo)
                    }
                }
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
}