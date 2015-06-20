//
//  DataStoreEntityName.swift
//  DataStore
//
//  Created by Jad Osseiran on 17/11/2014.
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
    
    /// Singleton instance of dictionary to keep track of the stored class names.
    private class var entityClassNamesDictionary: [String: String] {
        struct Singleton {
            static let instance = [String: String]()
        }
        return Singleton.instance
    }
    
    /**
     * Helper method to empty the cached entity class names.
     */
    public class func clearClassNameCache() {
        var cache = entityClassNamesDictionary
        cache.removeAll(keepCapacity: false)
    }
    
    /**
     * Method to return the correct entity name for a given class. If the 
     * class has a prefix which differs from the entity name in your model this 
     * method will allow you to give the project prefix and will return the 
     * correct name to use for methods such as! entityForName:.
     *
     * O(n)
     *
     * - parameter objectClass: The class for the managed object who's name will be returned.
     * - parameter classPrefix: The prefix which differs from the model entity name and the class name.
     *
     * - returns: The entity name for the given class, nil if the class given did not match any of the model's entities.
     */
    public func entityNameForObjectClass(objectClass: NSManagedObject.Type, withClassPrefix classPrefix: String?) -> String! {
        // Get a reference to the singleton names dictionary.
        var dictionary = DataStore.entityClassNamesDictionary
        
        // FIXME: When Apple sorts out how they will treat the Swift namespacing and class name retieving this can be improved on.
        let classString = NSStringFromClass(objectClass)
        let range = classString.rangeOfString(".", options: NSStringCompareOptions.CaseInsensitiveSearch, range: Range<String.Index>(start:classString.startIndex, end: classString.endIndex), locale: nil)
        let className = range != nil ? classString.substringFromIndex(range!.endIndex) : classString
        
        // Check if the value has already been calculated.
        var entityName = dictionary[className]
        
        if entityName != nil {
            // Reutrn the existing value.
            return entityName
        }
        
        // Look for the matching entity in the coordinator.
        for entity in persistentStoreCoordinator.managedObjectModel.entities {            
            if entity.managedObjectClassName == className {
                entityName = className
                break
            }
        }
        
        // If the entity was found save it for later and check for the prefix.
        if entityName != nil {
            if let prefix = classPrefix {
                let prefixCount = prefix.characters.count
                // Check if the prefix is valid.
                if className.hasPrefix(prefix) && className.characters.count > prefixCount {
                    // Adjust the entity name by removing the prefix.
                    let index: String.Index = advance(className.startIndex, prefixCount)
                    entityName = className.substringFromIndex(index)
                }
            }
            // Cache the entity name for later.
            dictionary[className] = entityName!
        }
        
        return entityName
    }
    
    /**
     * Method to return the correct entity name for a given class. Use this method
     * if the class has a prefix which does not differs from the entity name in
     * your model. If it does differ use entityNameForObjectClass:withClassPrefix:.
     *
     * O(n)
     *
     * - parameter objectClass: The class for the managed object who's name will be returned.
     *
     * - returns: The entity name for the given class, nil if the class given did not match any of the model's entities.
     */
    public func entityNameForObjectClass(objectClass: NSManagedObject.Type) -> String! {
        return entityNameForObjectClass(objectClass, withClassPrefix: nil)
    }
}