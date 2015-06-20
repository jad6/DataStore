//
//  DataStoreFileSystem.swift
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

import Foundation
import CoreData

public extension DataStore {

    public func placeStoreInLocalDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?) throws {
        try placeStoreInDirectoryTyoe(.Local, store: store, options: options)
    }
    
    public func placeStoreInCloudDirectory(store: NSPersistentStore, options: [NSObject: AnyObject]?) throws {
        try placeStoreInDirectoryTyoe(.Cloud, store: store, options: options)
    }
    
    // MARK: - Private

    private enum CoreDataDirectoryType {
        case Local, Cloud, Parent
    }

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
                try fileManager.createDirectoryAtPath(parentPath, withIntermediateDirectories: false, attributes: nil)
                /* TODO: Finish migration: rewrite code to move the next statement out of enclosing do/catch */
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