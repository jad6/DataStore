//
//  EntityName.swift
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
    
    /// Singleton instance of dictionary to keep track of the stored entity names.
    private class var cachedEntityNames: [String: String] {
        struct Singleton {
            static var instance = [String: String]()
        }
        return Singleton.instance
    }
    
    /**
     * Helper method to empty the cached entity class names.
     */
    public class func clearCachedEntityNames() {
        var cache = cachedEntityNames
        cache.removeAll(keepCapacity: false)
    }
    
    /**
     * Method to return the correct entity name for a given class name.
     *
     * - complexity: O(n)
     * - throws: An `InvalidEntityNameFetchRequest` error if no entity names were found or if multiple names were found to match.
     * - parameter classString: The class name for the managed object who's entity name will be returned. This can either
     * be a fully namespaced Swift classname like so `ModuleName.ClassName` or just contain the class name without the 
     * module namespacing (the latter is what Objective-C will be using).
     * - parameter classPrefix: The prefix which differs from the model entity name and the class name.
     * You would set this if your given class name is different from the entity name shown in the xcdatamodeld file.
     * - returns: The entity name for the given class name, `nil` if the error is populated.
     */
    public func entityNameForObjectClassString(classString: String, withClassPrefix classPrefix: String? = nil) throws -> String! {
        let className: String
        let classStringRange = Range<String.Index>(start: classString.startIndex, end: classString.endIndex)
        if let delimiterRange = classString.rangeOfString(".", options: NSStringCompareOptions.CaseInsensitiveSearch, range: classStringRange, locale: nil) {
            // We have module namespacing save our module name.
            className = classString.substringFromIndex(delimiterRange.endIndex)
        } else {
            // We do not have module namespacing so the class name will be what was passed down for us.
            className = classString
        }
        
        // Get a reference to the singleton names dictionary.
        var cache = DataStore.cachedEntityNames
        
        // Check if the value has already been calculated.
        if let cachedName = cache[classString] {
            // Reutrn the existing value.
            return cachedName
        }
        
        // Look for the matching entity in the coordinator.
        var foundPotentialNames = [String]()
        for entity in persistentStoreCoordinator.managedObjectModel.entities {
            // In the case where there is a module namespace then `classString` will not be equal to `className`.
            if entity.managedObjectClassName == classString || entity.managedObjectClassName == className {
                foundPotentialNames.append(entity.managedObjectClassName)
            }
        }
        
        if foundPotentialNames.count != 1 {
            throw NSError.invalidEntityNamesErrorFromMatches(foundPotentialNames, classString: classString)
        }
        
        // By this point the entity was found so save it for later.
        var entityName = foundPotentialNames.first!
        // Process the prefix discrepency if there is one
        if let prefix = classPrefix {
            let prefixCount = prefix.characters.count
            // Check if the prefix is valid.
            if className.hasPrefix(prefix) && className.characters.count > prefixCount {
                // Adjust the entity name by removing the prefix.
                let index: String.Index = className.startIndex.advancedBy(prefixCount)
                entityName = className.substringFromIndex(index)
            }
        }
        
        // Cache the entity name for later.
        cache[classString] = entityName
        // Return the found entity name.
        return entityName
    }
    
    /**
     * Method to return the correct entity name for a given class.
     *
     * - complexity: O(n)
     * - parameter objectClass: The class for the managed object who's entity name will be returned.
     * - parameter classPrefix: The prefix which differs from the model entity name and the class name.
     * You would set this if your given class name is different from the entity name shown in the xcdatamodeld file.
     * - returns: The entity name for the given class, nil if the error is populated.
     */
    public func entityNameForObjectClass(objectClass: NSManagedObject.Type, withClassPrefix classPrefix: String? = nil) throws -> String! {
        return try entityNameForObjectClassString(NSStringFromClass(objectClass), withClassPrefix: classPrefix)
    }
}