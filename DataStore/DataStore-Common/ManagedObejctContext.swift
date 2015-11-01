//
//  ManagedObejctContext.swift
//  DataStore
//
//  Created by Jad Osseiran on 12/11/2014.
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

public extension NSManagedObjectContext {
    
    /**
     Method to find ordered entities with a given predicate. The passed in error will
     be nil if the method succeeded. If the fetch fails nil is
     returned and the error parameter is populated.
     - throws: An error if something goes wrong in the fetch request.
     - note: If you are using Swift make sure that your `entityName` does not include the namespace.
   
     - parameter entityName: The entity name of for the managed object to find.
     - parameter predicate: The predicate to use for the NSFetchRequest
     - parameter sortDescriptors: An array of sort descriptors to order the results.
     - returns: An array with the found managed objects which match the given predicate.
     */
    public func findEntitiesForEntityName(entityName: String, withPredicate predicate: NSPredicate?, andSortDescriptors sortDescriptors: [NSSortDescriptor]?) throws -> [AnyObject] {
        // Create a request with the appropriate information.
        let request = NSFetchRequest(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        // Execute the fetch request.
        return try executeFetchRequest(request)
    }
    
    /**
     Method to find entities with a given predicate. The passed in error will
     be nil if the method succeeded. If the fetch fails nil is
     returned and the error parameter is populated.
     - throws: An error if something goes wrong in the fetch request.
     - note: If you are using Swift make sure that your `entityName` does not include the namespace.
   
     - parameter entityName: The entity name of for the managed object to find.
     - parameter predicate: The predicate to use for the NSFetchRequest
     - returns: An array with the found managed objects which match the given predicate.
     */
    public func findEntitiesForEntityName(entityName: String, withPredicate predicate: NSPredicate?) throws -> [AnyObject] {
        return try findEntitiesForEntityName(entityName,
            withPredicate: predicate,
            andSortDescriptors: nil)
    }
    
    /**
     Method which allows searching for objects by filtering on a specific
     key-value paring. If the no objects are found with the given key-value pair a
     new managed object is created and inserted in the calling managed object context.
     A callback closure is passed to allow modification of each of the resulting objects,
     typically to set their attributes.
     - throws: An error if something goes wrong in the fetch request.
     - note: If you are using Swift make sure that your `entityName` does not include the namespace.
   
     - note: If you are build for iOS 9+ or Mac OS X 10.11+ please consider using unique constraints.
     https://developer.apple.com/videos/wwdc/2015/?id=220
     - parameter entityName: The entity name of for the managed object to find.
     - parameter key: The key to use to find the possible existing objects. If no matching objects exist, it is used to set a value on the newly created object.
     - parameter value: The value to match with the given key to find an objects. If no matching  objects exist it is set on the given key for the newly created object.
     - parameter resultObjectHandler: A closure which will be called on each resulting object. These could be a newly created object or found objects.
     - returns: An array of managed objects matching the key-value paring or an array containing the newly created managed object.
     */
    public func findOrInsertEntitiesWithEntityName(entityName: String,
        whereKey key: String,
        equalsValue value: AnyObject,
        resultObjectHandler objectHandler: ((object: AnyObject, inserted: Bool) -> Void)?) throws -> [AnyObject] {
            // Create a request with the appropriate information.
            let request = NSFetchRequest(entityName: entityName)

            // If a key is a String then surround it with "s.
            let parsedValue: AnyObject = value is String ? "\"\(value)\"" : value
            // Build request predicate.
            request.predicate = NSPredicate(format: "\(key) == \(parsedValue)")

            var fetchError: NSError?
            // Check if the fetch will return objects.
            if countForFetchRequest(request, error: &fetchError) == 0 {
                if fetchError != nil {
                    throw fetchError!
                }

                // If there is no found object create and insert one.
                let newObject: AnyObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self)
                // Set the appropriate key-value pair.
                newObject.setValue(value, forKey: key)
                // Allow the caller to edit the new managed object.
                objectHandler?(object: newObject, inserted: true)

                return [newObject]
            } else {
                // The objects exist so fetch them and store them if the fetch was successful.
                let results = try executeFetchRequest(request)
                for object in results {
                    objectHandler?(object: object, inserted: false)
                }
                return results
            }
    }

    /**
     Method which returns all the objects for the given entity name.
     - throws: An error if something goes wrong in the fetch request.
     - note: If you are using Swift make sure that your `entityName` does not include the namespace.
   
     - parameter entityName: The entity name of for the managed object to find.
     - returns: An array containing all the managed objects for the given entity name.
     */
    public func findAllForEntityWithEntityName(entityName: String) throws -> [AnyObject] {
        return try executeFetchRequest(NSFetchRequest(entityName: entityName))
    }
    
    /**
     Helper method to insert a new object in the context.
     - note: If you are using Swift make sure that your `entityName` does not include the namespace.

     - parameter entityName: The entity name of for the managed object to find.
     - parameter insertion: Insertion closure to allow the setting up of the newly created object. nil if the creation was unsuccessful.
     */
    public func insertObjectWithEntityName(entityName: String, insertion: ((object: AnyObject) -> Void)?) {
        let newObject: AnyObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self)
        insertion?(object: newObject)
    }
}