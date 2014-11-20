//
//  ManagedObejctContext.swift
//  DataStore
//
//  Created by Jad Osseiran on 12/11/2014.
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

public extension NSManagedObjectContext {
    
    /**
     * Method to find ordered entities with a given predicate. The passed in error will
     * be nil if the method succeeded. If the fetch fails an empty array is
     * returned and the error parameter is populated.
     *
     * :param: entityName The entity name of for the managed object to find.
     * :param: predicate The predicate to use for the NSFetchRequest
     * :param: error An error which will be populated if something goes wrong in the fetch request.
     * :param: sortDescriptors An array of sort descriptors to order the results.
     *
     * :returns: An array with the found managed objects which match the given predicate.
     */
    public func findEntitiesForEntityName(entityName: String, withPredicate predicate: NSPredicate?, andSortDescriptors sortDescriptors: [NSSortDescriptor]?, error: NSErrorPointer) -> [NSManagedObject] {
        // Create a request with the appropriate information.
        let request = NSFetchRequest(entityName: entityName)
        request.predicate = predicate
        request.sortDescriptors = sortDescriptors
        
        // Execute the fetch request and attempt to downcast to an array of NSManagedObjects.
        let results = executeFetchRequest(request, error: error) as? [NSManagedObject]
        
        // Return the results or an empty array on fetch failure.
        return results != nil ? results! : [NSManagedObject]()
    }
    
    /**
     * Method to find entities with a given predicate. The passed in error will
     * be nil if the method succeeded. If the fetch fails an empty array is
     * returned and the error parameter is populated.
     *
     * :param: entityName The entity name of for the managed object to find.
     * :param: predicate The predicate to use for the NSFetchRequest
     * :param: error An error which will be populated if something goes wrong in the fetch request.
     *
     * :returns: An array with the found managed objects which match the given predicate.
     */
    public func findEntitiesForEntityName(entityName: String, withPredicate predicate: NSPredicate?, error: NSErrorPointer) -> [NSManagedObject] {
        return findEntitiesForEntityName(entityName,
            withPredicate: predicate,
            andSortDescriptors: nil,
            error: error)
    }
    
    /**
     * Method which allows searching for objects by filtering on a specific
     * key-value paring. If the no objects are found with the given key-value pair a
     * new managed object is created and inserted in the calling managed object context.
     * A callback closure is passed to allow modification of the newly created object, 
     * typically to set its attributes. If the fetch fails an empty array is
     * returned and the error parameter is populated.
     *
     * :param: entityName The entity name of for the managed object to find.
     * :param: key The key to use to find the possible existing objects. If no matching objects exist, it is used to set a value on the newly created object.
     * :param: value The value to match with the given key to find an objects. If no matching  objects exist it is set on the given key for the newly created object.
     * :param: error An error which will be populated if something goes wrong in the fetch request.
     * :param: insert A closure which will be called with the new object when it is created.
     *
     * :returns: An array of managed objects matching the key-value paring or an array containing the newly created managed object.
     */
    public func findEntitiesWithEntityName(entityName: String,
        wherKey key: String,
        equalsValue value: AnyObject,
        error: NSErrorPointer,
        orInsert insert: ((object: NSManagedObject) -> Void)?) -> [NSManagedObject] {
            // Create a request with the appropriate information.
            let request = NSFetchRequest(entityName: entityName)
            
            // If a key is a String then surround it with "s.
            let parsedValue: AnyObject = value is String ? "\"\(value)\"" : value
            // Build request predicate.
            request.predicate = NSPredicate(format: "\(key) == \(parsedValue)")
            
            // Initialise a variable to hold the found/created managed objects.
            var objects = [NSManagedObject]()
            // Check if the fetch will return objects.
            if countForFetchRequest(request, error: error) == 0 {
                // If there is no found object create and insert one.
                if let newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self) as? NSManagedObject {
                    // Set the appropriate key-value pair.
                    newObject.setValue(value, forKey: key)
                    // Allow the caller to edit the new managed object.
                    insert?(object: newObject)
                    
                    objects.append(newObject)
                }
            } else {
                // The objects exist so fetch them and store them if the fetch was successful.
                if let results = executeFetchRequest(request, error: error) as? [NSManagedObject] {
                    objects = results
                }
            }
            
            return objects
    }

    /**
     * Method which returns all the objects for the given entity name.
     *
     * :param: entityName The entity name of for the managed object to find.
     * :param: error An error which will be populated if something goes wrong in the fetch request.
     *
     * :returns: An array containing all the managed objects for the given entity name.
     */
    public func findAllForEntityWithEntityName(entityName: String, error: NSErrorPointer) -> [NSManagedObject] {
        let results = executeFetchRequest(NSFetchRequest(entityName: entityName), error: error) as? [NSManagedObject]
        
        return results != nil ? results! : [NSManagedObject]()
    }
    
    /**
     * Helper method to insert a new object in the context.
     *
     * :param: entityName The entity name of for the managed object to find.
     * :param: insertion Insertion closure to allow the setting up of the newly created object. nil if the creation was unsuccessful.
     */
    public func insertObjectWithEntityName(entityName: String, insertion: ((object: NSManagedObject) -> Void)?) {
        let newObject = NSEntityDescription.insertNewObjectForEntityForName(entityName, inManagedObjectContext: self) as NSManagedObject
        
        insertion?(object: newObject)
    }
}