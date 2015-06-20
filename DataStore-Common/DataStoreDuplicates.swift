//
//  DataStoreDuplicates.swift
//  DataStore
//
//  Created by Jad Osseiran on 25/11/2014.
//  Copyright (c) 2015 Jad Osseiran. All rights reserved.
//

import CoreData

public extension DataStore {
    
    /**
     * Method which removes duplicates for an entity.
     * THROWS: An error if anything goes wrong
     *
     * - parameter entityName: The name of the entity for which to remove duplicates.
     * - parameter key: The key attribute to use for unique identification of the object.
     * - parameter type: The attribute type of the identification key.
     * - parameter duplicateToDelete: A closure which will be called when two duplicate objects are found. Return the duplicate to delete.
     * - returns: True if the operation succeeded.
     */
    public func removeDuplicatesInStoreForEntityName(entityName: String,
        withUniqueAttributeKey key: String,
        andAttributeType type: NSAttributeType,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) throws {
            // Create an expression description to get the count for an entity
            // name with the give key.
            let countExpressionDescription = countExpressionDescriptionForEntityName(entityName,
                withUniqueAttributeKey: key,
                andAttributeType: type)

            // Get the entity decription for the given entity name.
            let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: writerManagedObjectContext)
            // If the attribute eists for the given key.
            if let uniqueAttribute: AnyObject = entity?.attributesByName[key] {
                // TODO: (Jad) re-visit this
                // Get the info dictionaries for the duplicate.
                try fetchDuplicateInfo(entityName: entityName,
                    uniqueAttribute: uniqueAttribute,
                    countExpressionDescription: countExpressionDescription)
            }
    }

    // MARK: - Private

    /**
     * Filter out unique values that have no duplicates.
     *
     * - parameter valuesWithDupes: Dctionary of values without duplicates
     * - parameter key: The key attribute to use for unique identification of the object.
     * - returns: An array of duplicated values.
     */
    private func retrieveDuplicateFromValues(valuesWithDupes: [AnyObject], withUniqueAttributeKey key: String) -> [AnyObject] {
        // Create an array to store the duplicate values.
        var values = [AnyObject]()
        // Iterate through each duplicate dictionaries.
        for dictionary in valuesWithDupes {
            // Get the count for the iterated dictionary.
            if let count = dictionary["count"] as? NSNumber where count.integerValue > 1{
                // If a duplicate is found then add the object to the values to return.
                if let object: AnyObject = dictionary[key] {
                    values.append(object)
                }
            }
        }
        return values
    }
    
    /**
     * Fetches the number of times each unique value appears in the store.
     * THROWS: An error if anything goes wrong.
     * 
     * - parameter entityName: The name of the entity for which to remove duplicates.
     * - parameter uniqueAttribute: The value of the unique attribute to group the fetch with.
     * - parameter countExpressionDescription: The count description expression for the fetch.
     * - returns: An array of dictionaries containing the duplicated info, nil if an error was ecountered.
     */
    private func fetchDuplicateInfo(entityName entityName: String,
        uniqueAttribute: AnyObject,
        countExpressionDescription: NSExpressionDescription) throws -> [AnyObject] {
            let fetchRequest = NSFetchRequest(entityName: entityName)
            fetchRequest.propertiesToFetch = [uniqueAttribute, countExpressionDescription]
            fetchRequest.propertiesToGroupBy = [uniqueAttribute]
            fetchRequest.resultType = .DictionaryResultType

            return try writerManagedObjectContext.executeFetchRequest(fetchRequest)
    }
    
    /**
     * Method to return a conut expression description to be used to find duplicates.
     *
     * - parameter entityName: The name of the entity for which to remove duplicates.
     * - parameter key: The key attribute to use for unique identification of the object.
     * - parameter type: The attribute type of the identification key.
     * - returns: Expression description to get the count for an entity name with the give key
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
     * THROWS: An error if anything goes wrong.
     *
     * - parameter dupes: An array of duplicated objects.
     * - parameter key: The key attribute to use for unique identification of the object.
     * - parameter duplicateToDelete: A closure which will be called when two duplicate objects are found. Return the duplicate to delete.
     * - returns: True if the operation succeeded.
     */
    private func deleteDuplicates(dupes: [AnyObject],
        withUniqueAttributeKey key: String,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) throws {
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
                            throw deleteError
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
    }
}
