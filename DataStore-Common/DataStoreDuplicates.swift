//
//  DataStoreDuplicates.swift
//  DataStore
//
//  Created by Jad Osseiran on 25/11/2014.
//  Copyright (c) 2014 Jad Osseiran. All rights reserved.
//

import CoreData

public extension DataStore {
    
    /**
     * Method which removes duplicates for an entity.
     *
     * :param: entityName The name of the entity for which to remove duplicates.
     * :param: key The key attribute to use for unique identification of the object.
     * :param: type The attribute type of the identification key.
     * :param: error An error pointer populated if anything goes wrong.
     * :param: duplicateToDelete A closure which will be called when two duplicate objects are found. Return the duplicate to delete.
     *
     * :returns: True if the operation succeeded.
     */
    public func removeDuplicatesInStoreForEntityName(entityName: String,
        withUniqueAttributeKey key: String,
        andAttributeType type: NSAttributeType,
        error: NSErrorPointer,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) -> Bool {
            // Create an expression description to get the count for an entity 
            // name with the give key.
            let countExpressionDescription = countExpressionDescriptionForEntityName(entityName,
                withUniqueAttributeKey: key,
                andAttributeType: type)

            // Get the entity decription for the given entity name.
            let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: writerManagedObjectContext)
            // If the attribute eists for the given key.
            if let uniqueAttribute: AnyObject = entity?.attributesByName[key] {
                // Get the info dictionaries for the duplicate.
                let fetchedDictionaries = fetchDuplicateInfo(entityName: entityName,
                    uniqueAttribute: uniqueAttribute,
                    countExpressionDescription: countExpressionDescription,
                    error: error)
                // Return unsuccessfully in the case of an error.
                if error != nil {
                    return false
                }
                
                // Get the duplicate values from the info dictionaries.
                let duplicateValues = retrieveDuplicateFromValues(fetchedDictionaries!, withUniqueAttributeKey: key)
                // Look for the keys in the duplicate dictionaries.
                let predicate = NSPredicate(format: "\"\(key)\" IN (\(duplicateValues)")
                // Create a fetch request using the prdeicate and entityName.
                let dupeFetchRequest = NSFetchRequest(entityName: entityName)
                dupeFetchRequest.includesPendingChanges = false
                dupeFetchRequest.predicate = predicate

                // Execute the fetch request.
                let fetchResult = writerManagedObjectContext.executeFetchRequest(dupeFetchRequest, error: error)
                // Return unsuccessfully in the case of an error.
                if error != nil {
                    return false
                }
                
                // Finally delete the duplicate which were fetched using the 
                // deletion algorithm passed in duplicateToDelete.
                if let dupes = fetchResult {
                    deleteDuplicates(dupes,
                        withUniqueAttributeKey: key,
                        error: error,
                        duplicateToDelete: duplicateToDelete)
                }
            }
            
            return error == nil
    }
    
    // MARK: - Private
    
    /**
     * Filter out unique values that have no duplicates.
     *
     * :param: valuesWithDupes Dctionary of values without duplicates
     * :param: key The key attribute to use for unique identification of the object.
     * 
     * :returns: An array of duplicated values.
     */
    private func retrieveDuplicateFromValues(valuesWithDupes: [AnyObject], withUniqueAttributeKey key: String) -> [AnyObject] {
        // Create an array to store the duplicate values.
        var values = [AnyObject]()
        // Iterate through each duplicate dictionaries.
        for dictionary in valuesWithDupes {
            // Get the count for the iterated dictionary.
            if let count = dictionary["count"] as? NSNumber {
                // If a duplicate is found then add the object to the values to return.
                if count.integerValue > 1 {
                    if let object: AnyObject = dictionary[key] {
                        values.append(object)
                    }
                }
            }
        }
        return values
    }
    
    /**
     * Fetches the number of times each unique value appears in the store.
     * 
     * :param: entityName The name of the entity for which to remove duplicates.
     * :param: uniqueAttribute The value of the unique attribute to group the fetch with.
     * :param: countExpressionDescription The count description expression for the fetch.
     * :param: error An error pointer populated if anything goes wrong.
     * 
     * :returns: An array of dictionaries containing the duplicated info, nil if an error was ecountered.
     */
    private func fetchDuplicateInfo(#entityName: String,
        uniqueAttribute: AnyObject,
        countExpressionDescription: NSExpressionDescription,
        error: NSErrorPointer) -> [AnyObject]? {
            
            let fetchRequest = NSFetchRequest(entityName: entityName)
            fetchRequest.propertiesToFetch = [uniqueAttribute, countExpressionDescription]
            fetchRequest.propertiesToGroupBy = [uniqueAttribute]
            fetchRequest.resultType = .DictionaryResultType
            
            return writerManagedObjectContext.executeFetchRequest(fetchRequest, error: error)
    }
    
    /**
     * Method to return a conut expression description to be used to find duplicates.
     *
     * :param: entityName The name of the entity for which to remove duplicates.
     * :param: key The key attribute to use for unique identification of the object.
     * :param: type The attribute type of the identification key.
     * 
    * :returns: Expression description to get the count for an entity name with the give key
     */
    private func countExpressionDescriptionForEntityName(entityName: String,
        withUniqueAttributeKey key: String,
        andAttributeType type: NSAttributeType) -> NSExpressionDescription {
            // Set the expression.
            let countExpression = NSExpression(format: "count:(\"\(key)\")")
            // Populate the expression description.
            let countExpressionDescription = NSExpressionDescription()
            countExpressionDescription.name = "count"
            countExpressionDescription.expression = countExpression
            countExpressionDescription.expressionResultType = type
            
            return countExpressionDescription
    }
    
    /**
     * Helper method to delete the duplicates in an array using a given algorithm.
     *
     * :param: dupes An array of duplicated objects.
     * :param: key The key attribute to use for unique identification of the object.
     * :param: error An error pointer populated if anything goes wrong.
     * :param: duplicateToDelete A closure which will be called when two duplicate objects are found. Return the duplicate to delete.
     *
     * :returns: True if the operation succeeded.
     */
    private func deleteDuplicates(dupes: [AnyObject],
        withUniqueAttributeKey key: String,
        error: NSErrorPointer,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) -> Bool {
            // Store a reference to the previous object seen in the iteration.
            var previous: AnyObject?
            // Iterate through each duplicate.
            for current in dupes {
                if previous != nil {
                    // Get the current & previous value.
                    let currentValue = current.valueForKey(key) as? NSObject
                    let prevValue = previous!.valueForKey(key) as? NSObject
                    // If the values are the same then they are duplicated.
                    if currentValue == prevValue {
                        // Find out which duplicate to delete.
                        let deleteObject = duplicateToDelete(left: current, right: previous!)
                        // If the delete object is not the either of the two which 
                        // were passed on then create an error and terminate.
                        if deleteObject !== current || deleteObject !== previous {
                            let deleteError = NSError(domain: ErrorConstants.domain, code: ErrorConstants.Codes.Duplication.invalidDeleteObject, userInfo: [NSLocalizedDescriptionKey: "Invalid duplicate object to delete", NSLocalizedFailureReasonErrorKey: "The returned object: \(deleteObject) is not one of the given duplicates: \(previous) or \(current)", NSLocalizedRecoverySuggestionErrorKey: "Please return one of the given objects"])
                            error.memory = deleteError
                            
                            return false
                        } else {
                            // Delete the selected object.
                            writerManagedObjectContext.deleteObject(deleteObject)
                            // Update the previous reference if the old referred
                            // object was deleted.
                            if deleteObject === previous {
                                previous = current
                            }
                        }
                    } else {
                        previous = current
                    }
                } else {
                    previous = current
                }
            }
            
            return true
    }
}
