//
//  DataStoreReset.swift
//  DataStore
//
//  Created by Jad Osseiran on 29/11/2014.
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

public extension DataStore {

    /**
     * Enum which dictates how the store will be reset when the data store is reset.
     */
    @objc public enum StoreResetOption: Int {
        /// Uses the current store options.
        case CopyExisting
        /// Removes local data and creates store from cloud data.
        case RebuildFromCloud
        /// Stops the syncing to iCloud and moves the stores to different URLs.
        case DisableCloud
        /// Clears all options.
        case Clear
    }
    
    public func deleteAllObjectsWithEntityNames(entityNames: [String]) throws {
        try deleteAllObjectsWithEntityNames(entityNames, onContext: mainManagedObjectContext)
    }
    
    public func deleteAllObjectsWithEntityNamesInBackground(entityNames: [String]) throws {
        try deleteAllObjectsWithEntityNames(entityNames, onContext: backgroundManagedObjectContext)
    }
    
    private func deleteAllObjectsWithEntityNames(entityNames: [String], onContext context: NSManagedObjectContext) throws {
        var failedEntitiesInfo = [String: NSError]()
        
        for entityName in entityNames {
            let fetchRequest = NSFetchRequest(entityName: entityName)
            if #available(iOS 9, OSX 10.11, *) {
                do {
                    let batchRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
                    try persistentStoreCoordinator.executeRequest(batchRequest, withContext: context)
                } catch let error as NSError {
                    failedEntitiesInfo[entityName] = error
                }
            } else {
                do {
                    if let objects = try context.executeFetchRequest(fetchRequest) as? [NSManagedObject] {
                        for object in objects {
                            context.deleteObject(object)
                        }
                    } else {
                        throw DataStoreError.DeleteNonManagedObject
                    }
                } catch let error as NSError {
                    failedEntitiesInfo[entityName] = error
                }
            }
        }
    
        // Reset the contexts before the save to make sure we are on an empty state.
        self.resetContexts()
        
        if failedEntitiesInfo.count > 0 {
            // There was an error encountered in the deletion. report it back.
            throw failedDeletionErrorForEntitieNames(failedEntitiesInfo)
        }
    }
    
    /**
     * Method to reset the Core Data environment. This erases the data in the
     * persistent stores as well as! reseting all managed object contexts.
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
