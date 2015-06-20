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
     * - complexity: O(n)
     * - returns: true if the process is successful.
     */
    public func reset() throws {
        try reset { store in .CopyExisting }
    }

    public func reset(newStoreOption: (store: NSPersistentStore) -> StoreResetOption) throws {
        var resetError: NSError?

        // Reset all contexts.
        self.resetContexts()

        // Make sure to perform the reset on closures to avoid deadlocks.
        writerManagedObjectContext.performBlockAndWait() {
            self.persistentStoreCoordinator.performBlockAndWait() {
                // Retrieve the stores which were coordinated.
                let stores = self.persistentStoreCoordinator.persistentStores

                do {
                    if #available(iOS 9, OSX 10.11, *) {
                        try self.replaceStores(stores, newStoreOption: newStoreOption)
                    } else {
                        try self.replaceStoresManually(stores, newStoreOption: newStoreOption)
                    }
                } catch let error as NSError {
                    resetError = error
                } catch {
                    fatalError()
                }
            }
        }

        if let error = resetError {
            throw error
        }
    }

    // MARK: - Private Methods

    /**
     * Method to reset the Core Data environment. This erases the data in the
     * persistent stores as well as reseting all managed object contexts.
     * Further, depening on the option cloud data can also be reset.
     * THROWS: The error if an error is encountered in the process.
     *
     * - complexity: O(n)
     * - parameter newStoreOption: A closure to return a reset option for the given store.
     */
    @available(iOS 8, OSX 10.10, *)
    private func replaceStoresManually(stores: [NSPersistentStore], newStoreOption: (store: NSPersistentStore) -> StoreResetOption) throws {
        let fileManager = NSFileManager.defaultManager()
        for store in stores {
            // Remove each persistent stores.
            try self.persistentStoreCoordinator.removePersistentStore(store)

            // Remove the files if they exist.
            if let storeURL = store.URL {
                if let storePath = storeURL.path where fileManager.fileExistsAtPath(storePath) {
                    // Remove the file where the store used to live.
                    try fileManager.removeItemAtURL(storeURL)
                }
            }
        }

        for store in stores {
            // Get the correct options.
            let options = try self.resetOptionsForOption(newStoreOption(store: store), onStore: store)

            // create new fresh persistent stores.
            try self.persistentStoreCoordinator.addPersistentStoreWithType(store.type, configuration: store.configurationName, URL: store.URL, options: options)
        }
    }

    @available(iOS 9, OSX 10.11, *)
    private func replaceStores(stores: [NSPersistentStore], newStoreOption: (store: NSPersistentStore) -> StoreResetOption) throws {
        for store in stores {
            if let storeURL = store.URL {
                // Get the correct options.
                let options = try self.resetOptionsForOption(newStoreOption(store: store), onStore: store)

                // FIXME: This is 99% wrong I am pretty sure.
                try self.persistentStoreCoordinator.replacePersistentStoreAtURL(storeURL, destinationOptions: options, withPersistentStoreFromURL: storeURL, sourceOptions: options, storeType: "blah")
            }
        }
    }

    private func resetOptionsForOption(option: StoreResetOption, onStore store: NSPersistentStore) throws -> [NSObject: AnyObject]? {
        let options = store.options

        switch option {
        case .CopyExisting:
            return options
        case .Clear:
            if let storeURL = store.URL {
                try NSPersistentStoreCoordinator.removeUbiquitousContentAndPersistentStoreAtURL(storeURL, options: nil)
                try placeStoreInLocalDirectory(store, options: nil)
            }
            return nil
        case .RebuildFromCloud:
            // FIXME: Swift can suck my dick
//            options?[NSPersistentStoreRebuildFromUbiquitousContentOption] = true
            return options
        case .DisableCloud:
            // FIXME: Swift can suck my dick
//            options?[NSPersistentStoreRemoveUbiquitousMetadataOption] = true
//            options?[NSPersistentStoreUbiquitousContentNameKey] = nil

            try placeStoreInCloudDirectory(store, options: options)
            return options
        }
    }
}
