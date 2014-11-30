//
//  DataStoreFileSystem.swift
//  DataStore
//
//  Created by Jad Osseiran on 29/11/2014.
//  Copyright (c) 2014 Jad Osseiran. All rights reserved.
//

import Foundation
import CoreData

public extension DataStore {
    
    private enum CoreDataDirectoryType {
        case Local, Cloud, Parent
    }
    
    // MARK: - Public Methods
    
    public func placeStoreInLocalDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?,  error: NSErrorPointer) -> Bool {
        return placeStoreInDirectoryTyoe(.Local, store: store, options: options, error: error)
    }
    
    public func placeStoreInCloudDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?,  error: NSErrorPointer) -> Bool {
        return placeStoreInDirectoryTyoe(.Cloud, store: store, options: options, error: error)
    }
    
    // MARK: - Private Methods
    
    private func placeStoreInDirectoryTyoe(type: CoreDataDirectoryType, store: NSPersistentStore, options: [NSObject: AnyObject]?, error: NSErrorPointer) -> Bool {
        
        let migrateStore = { (store: NSPersistentStore, toPath: String,  error: NSErrorPointer) -> Void in
            if let newStoreURL = NSURL(fileURLWithPath: toPath) {
                self.persistentStoreCoordinator.migratePersistentStore(store, toURL: newStoreURL , options: options, withType: store.type, error: error)
            }
        }
        
        let fileManager = NSFileManager.defaultManager()
        
        if let storePath = store.URL?.path {
            let path = directoryPathForType(type)
            let parentPath = directoryPathForType(.Parent)
                        
            if fileManager.fileExistsAtPath(path) {
                migrateStore(store, path, error)
            } else {
                if fileManager.createDirectoryAtPath(parentPath, withIntermediateDirectories: false, attributes: nil, error: error) {
                    if error != nil {
                        return false
                    }
                    
                    migrateStore(store, path, error)
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
            deleteDirectoryIfEmptyAtPath(otherPath, fileManager: fileManager, error: error)
        }
        
        return error == nil
    }
    
    private func deleteDirectoryIfEmptyAtPath(path: String, fileManager: NSFileManager, error: NSErrorPointer) {
        
        if let files = fileManager.contentsOfDirectoryAtPath(path, error: error) as? [String] {
            
            for file in files {
                let fullPath = path.stringByAppendingPathComponent(file)
                if let subFiles = fileManager.contentsOfDirectoryAtPath(fullPath, error: error) {
                    if subFiles.count == 0 {
                        let result = fileManager.removeItemAtPath(fullPath, error: error)
                    } else {
                        deleteDirectoryIfEmptyAtPath(fullPath, fileManager: fileManager, error: error)
                    }
                }
            }
        }
    }
    
    private func directoryPathForType(type: CoreDataDirectoryType) -> String {
        let directories = NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, false)
        
        let documentDirectory = directories.last as? String
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