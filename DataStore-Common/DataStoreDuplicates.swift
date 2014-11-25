//
//  DataStoreDuplicates.swift
//  DataStore
//
//  Created by Jad Osseiran on 25/11/2014.
//  Copyright (c) 2014 Jad Osseiran. All rights reserved.
//

import CoreData

extension DataStore {
    
    public func removeDuplicatesInStoreForEntityName(entityName: String,
        withUniqueAttributeKey key: String,
        andAttributeType type: NSAttributeType,
        error: NSErrorPointer,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) {
            let countExpressionDescription = countExpressionDescriptionForEntityName(entityName,
                withUniqueAttributeKey: key,
                andAttributeType: type)
            
            let entity = NSEntityDescription.entityForName(entityName, inManagedObjectContext: writerManagedObjectContext)
            if let uniqueAttribute: AnyObject = entity?.attributesByName[key] {
                
                let fetchedDictionaries = fetchDuplicateDictionaries(entityName: entityName,
                    uniqueAttribute: uniqueAttribute,
                    countExpressionDescription: countExpressionDescription,
                    error: error)
                if error != nil {
                    return
                }
                
                let duplicateValues = retrieveDuplicateFromValues(fetchedDictionaries, withUniqueAttributeKey: key)

                let predicate = NSPredicate(format: "\"\(key)\" IN (\(duplicateValues)")
                let dupeFetchRequest = NSFetchRequest(entityName: entityName)
                dupeFetchRequest.includesPendingChanges = false
                dupeFetchRequest.predicate = predicate

                let fetchResult = writerManagedObjectContext.executeFetchRequest(dupeFetchRequest, error: error)
                if error != nil {
                    return
                }
                
                if let dupes = fetchResult {
                    deleteDuplicates(dupes,
                        withUniqueAttributeKey: key,
                        error: error,
                        duplicateToDelete: duplicateToDelete)
                }
            }
    }
    
    // MARK: - Private
    
    private func deleteDuplicates(dupes: [AnyObject],
        withUniqueAttributeKey key: String,
        error: NSErrorPointer,
        duplicateToDelete: (left: AnyObject, right: AnyObject) -> NSManagedObject) {
            var prevObject: AnyObject?
            for duplicate in dupes {
                if prevObject != nil {
                    let dupeValue = duplicate.valueForKey(key) as? NSObject
                    let prevValue = prevObject!.valueForKey(key) as? NSObject
                    if dupeValue == prevValue {
                        let deleteObject = duplicateToDelete(left: duplicate, right: prevObject!)
                        
                        if deleteObject !== duplicate || deleteObject !== prevObject {
                            let deleteError = NSError(domain: ErrorConstants.domain, code: ErrorConstants.Codes.Duplication.invalidDeleteObject, userInfo: [NSLocalizedDescriptionKey: "Invalid duplicate object to delete", NSLocalizedFailureReasonErrorKey: "The returned object: \(deleteObject) is not one of the given duplicates: \(prevObject) or \(duplicate)", NSLocalizedRecoverySuggestionErrorKey: "Please return one of the given objects"])
                            error.memory = deleteError
                        } else {
                            writerManagedObjectContext.deleteObject(deleteObject)
                            if deleteObject === prevObject {
                                prevObject = duplicate
                            }
                        }
                    } else {
                        prevObject = duplicate
                    }
                } else {
                    prevObject = duplicate
                }
            }
    }
    
    // Filter out unique values that have no duplicates.
    private func retrieveDuplicateFromValues(valuesWithDupes: [AnyObject], withUniqueAttributeKey key: String) -> [AnyObject] {
        var values = [AnyObject]()
        for dictionary in valuesWithDupes {
            if let count = dictionary["count"] as? NSNumber {
                if count.integerValue > 1 {
                    if let object: AnyObject = dictionary[key]? {
                        values.append(object)
                    }
                }
            }
        }
        return values
    }
    
    // Fetch the number of times each unique value appears in the store.
    // The context returns an array of dictionaries, each containing a
    // unique value and the number of times that value appeared in the store
    private func fetchDuplicateDictionaries(#entityName: String,
        uniqueAttribute: AnyObject,
        countExpressionDescription: NSExpressionDescription,
        error: NSErrorPointer) -> [AnyObject] {
            
            let fetchRequest = NSFetchRequest(entityName: entityName)
            fetchRequest.propertiesToFetch = [uniqueAttribute, countExpressionDescription]
            fetchRequest.propertiesToGroupBy = [uniqueAttribute]
            fetchRequest.resultType = .DictionaryResultType
            
            var fetchedDictionaries = writerManagedObjectContext.executeFetchRequest(fetchRequest, error: error)
            
            return fetchedDictionaries ?? [AnyObject]()
    }
    
    private func countExpressionDescriptionForEntityName(entityName: String,
        withUniqueAttributeKey key: String,
        andAttributeType type: NSAttributeType) -> NSExpressionDescription {
            let countExpression = NSExpression(format: "count:(\"\(key)\")")
            let countExpressionDescription = NSExpressionDescription()
            countExpressionDescription.name = "count"
            countExpressionDescription.expression = countExpression
            countExpressionDescription.expressionResultType = type
            
            return countExpressionDescription
    }
}
