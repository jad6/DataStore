//
//  DataStoreReset.swift
//  DataStore
//
//  Created by Jad Osseiran on 29/11/2014.
//  Copyright (c) 2015 Jad Osseiran. All rights reserved.
//

import CoreData

public extension DataStore {

    /**
     * Enum which dictates how the store will be reset when the data store is reset.
     */
    public enum StoreResetOption {
        /// Uses the current store options.
        case CopyExisting
        /// Removes local data and creates store from cloud data.
        case RebuildFromCloud
        /// Stops the syncing to iCloud and moves the stores to different URLs.
        case DisableCloud
        /// Clears all options.
        case Clear
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the
     * persistent stores as! well as! reseting all managed object contexts.
     *
     * O(n)
     *
     * :param: error The error which is populated if an error is encountered in the process.
     *
     * :returns: true if the process is successful.
     */
    public func reset(error: NSErrorPointer) -> Bool {
        return reset(error) { store in .CopyExisting }
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the
     * persistent stores as! well as! reseting all managed object contexts.
     * Further, depening on the option cloud data can also be reset.
     *
     * O(n)
     *
     * :param: error The error which is populated if an error is encountered in the process.
     * :param: newStoreOption A closure to return a reset option for the given store.
     *
     * :returns: true if the process is successful.
     */
    public func reset(error: NSErrorPointer, newStoreOption: (store: NSPersistentStore) -> StoreResetOption) -> Bool {
        var resetSuccess = true
        
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
                        // Get the correct options.
                        let option = newStoreOption(store: store)
                        let options = self.resetOptionsForOption(option, onStore: store, error: error)
                        // If there is an error return unsuccessfully.
                        if error != nil {
                            resetSuccess = false
                            return
                        }
                        
                        // create new fresh persistent stores.
                        let addSuccess = self.persistentStoreCoordinator.addPersistentStoreWithType(store.type, configuration: store.configurationName, URL: store.URL, options: options, error: error)
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
    
    // MARK: - Protected Methods
    
    private func resetOptionsForOption(option: StoreResetOption, onStore store: NSPersistentStore, error: NSErrorPointer) -> [NSObject: AnyObject]? {
        var options = store.options
        switch option {
        case .CopyExisting:
            return options
        case .Clear:
            if let storeURL = store.URL {
                NSPersistentStoreCoordinator.removeUbiquitousContentAndPersistentStoreAtURL(storeURL, options: nil, error: error)
                placeStoreInLocalDirectory(store, options: nil, error: error)
            }
            return nil
        case .RebuildFromCloud:
            options?[NSPersistentStoreRebuildFromUbiquitousContentOption] = true
            return options
        case .DisableCloud:
            options?[NSPersistentStoreRemoveUbiquitousMetadataOption] = true
            options?[NSPersistentStoreUbiquitousContentNameKey] = nil
            
            placeStoreInCloudDirectory(store, options: options, error: error)
            
            return options
        }
    }
}
