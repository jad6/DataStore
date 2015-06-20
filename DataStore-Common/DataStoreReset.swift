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
     * - parameter error: The error which is populated if an error is encountered in the process.
     *
     * - returns: true if the process is successful.
     */
    public func reset() throws {
        try reset { store in .CopyExisting }
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the
     * persistent stores as well as reseting all managed object contexts.
     * Further, depening on the option cloud data can also be reset.
     *
     * O(n)
     *
     * - parameter newStoreOption: A closure to return a reset option for the given store.
     * - throws error: The error if an error is encountered in the process.
     */
    public func reset(newStoreOption: (store: NSPersistentStore) -> StoreResetOption) throws {
        var resetError: NSError?

        // Reset all contexts.
        self.resetContexts()

        // Make sure to perform the reset on closures to avoid deadlocks.
        writerManagedObjectContext.performBlockAndWait() {
            self.persistentStoreCoordinator.performBlockAndWait() {
                // Retrieve the stores which were coordinated.
                let stores = self.persistentStoreCoordinator.persistentStores

                let fileManager = NSFileManager.defaultManager()
                for store in stores {
                    // Remove each persistent stores.
                    do {
                        try self.persistentStoreCoordinator.removePersistentStore(store)

                        // Remove the files if they exist.
                        if let storeURL = store.URL {
                            if let storePath = storeURL.path {
                                if fileManager.fileExistsAtPath(storePath) {
                                    do {
                                        // Remove the file where the store used to live.
                                        try fileManager.removeItemAtURL(storeURL)
                                    } catch let error as NSError {
                                        resetError = error
                                    } catch {
                                        fatalError()
                                    }
                                }
                            }
                        }
                    } catch let error as NSError {
                        resetError = error
                    } catch {
                        fatalError()
                    }
                }

                if (resetError == nil) {
                    for store in stores {
                        do {
                            // Get the correct options.
                            let options = try self.resetOptionsForOption(newStoreOption(store: store), onStore: store)
                            do {
                                // create new fresh persistent stores.
                                try self.persistentStoreCoordinator.addPersistentStoreWithType(store.type, configuration: store.configurationName, URL: store.URL, options: options)
                            } catch let error as NSError {
                                resetError = error
                            } catch {
                                fatalError()
                            }
                        } catch let error as NSError {
                            resetError = error
                        } catch {
                            fatalError()
                        }
                    }
                }
            }
        }

        if resetError != nil {
            throw resetError!
        }
    }

    // MARK: - Protected Methods

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
