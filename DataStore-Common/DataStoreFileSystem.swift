//
//  DataStoreFileSystem.swift
//  DataStore
//
//  Created by Jad Osseiran on 29/11/2014.
//  Copyright (c) 2015 Jad Osseiran. All rights reserved.
//

import Foundation
import CoreData

public extension DataStore {
    
    private enum CoreDataDirectoryType {
        case Local, Cloud, Parent
    }
    
    // MARK: - Public Methods
    
    public func placeStoreInLocalDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?) throws {
        try placeStoreInDirectoryTyoe(.Local, store: store, options: options)
    }
    
    public func placeStoreInCloudDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?) throws {
        try placeStoreInDirectoryTyoe(.Cloud, store: store, options: options)
    }
    
    // MARK: - Private Methods

    private func migrateStore(store: NSPersistentStore, withOptions options: [NSObject: AnyObject]?, toPath: String) throws {
        let newStoreURL = NSURL(fileURLWithPath: toPath)
        try self.persistentStoreCoordinator.migratePersistentStore(store, toURL: newStoreURL , options: options, withType: store.type)
    }

    private func placeStoreInDirectoryTyoe(type: CoreDataDirectoryType, store: NSPersistentStore, options: [NSObject: AnyObject]?) throws {
        let fileManager = NSFileManager.defaultManager()
        
        if store.URL?.path != nil {
            let path = directoryPathForType(type)
            let parentPath = directoryPathForType(.Parent)
                        
            if fileManager.fileExistsAtPath(path) {
                try migrateStore(store, withOptions: options, toPath: path)
            } else {
                do {
                    try fileManager.createDirectoryAtPath(parentPath, withIntermediateDirectories: false, attributes: nil)
                    /* TODO: Finish migration: rewrite code to move the next statement out of enclosing do/catch */
                } catch let error {
                    throw error
                }
            }
            
            var otherType: CoreDataDirectoryType!
            switch type {
            case .Local:
                otherType = .Cloud
            case .Cloud:
                otherType = .Local
            case .Parent:
                otherType = nil
            }
            
            let otherPath = directoryPathForType(otherType)
            try deleteDirectoryIfEmptyAtPath(otherPath, fileManager: fileManager)
        }
    }
    
    private func deleteDirectoryIfEmptyAtPath(path: String, fileManager: NSFileManager) throws {
        let files = try fileManager.contentsOfDirectoryAtPath(path)

        for file in files {
            let fullPath = path.stringByAppendingPathComponent(file)
            
            let subFiles = try fileManager.contentsOfDirectoryAtPath(fullPath)
            if subFiles.count == 0 {
                try fileManager.removeItemAtPath(fullPath)
            } else {
                try deleteDirectoryIfEmptyAtPath(fullPath, fileManager: fileManager)
            }
        }
    }

    private func directoryPathForType(type: CoreDataDirectoryType) -> String {
        let directories = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, false)
        
        let documentDirectory = directories.last
        assert(documentDirectory != nil)
        
        var name: String!
        switch type {
        case .Local:
            name = "LocalCoreData"
        case .Cloud:
            name = "CloudCoreData"
        case .Parent:
            return documentDirectory!
        }
        return documentDirectory!.stringByAppendingString(name)
    }
}