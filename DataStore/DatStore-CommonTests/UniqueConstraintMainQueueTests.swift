//
//  UniqueConstraintTests.swift
//  DataStore
//
//  Created by Jad Osseiran on 10/25/15.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//

import XCTest
import Foundation
import CoreData

class UniqueConstraintTests: DataStoreTests, DataStoreUniqunessTests {
    
    // MARK: Sync
    
    func testErrorMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .ErrorMergePolicyType)
        
        insertSameIDObjectsInMainContext { error in
            let conflictList = error.userInfo["conflictList"] as? [NSObject]
            XCTAssertEqual(conflictList?.count, 1)
            
            let constraintConflict = conflictList?.first as? NSConstraintConflict
            XCTAssertNotNil(constraintConflict)
            XCTAssertEqual(constraintConflict!.conflictingObjects.count, 2)
        }
    }
    
    func testMergeByPropertyStoreTrumpMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyStoreTrumpMergePolicyType)

        insertSameIDObjectsInMainContext()
        
        dataStore.performClosureAndWait { [unowned self] context in
            do {
                let results = try context.findAllForEntityWithEntityName(self.entityName) as! [CreditCard]

                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first!.cvv, self.cardTwoCVV)
            } catch let error {
                XCTFail("Fetch encountered error: \(error)")
            }
        }
    }
    
    func testMergeByPropertyObjectTrumpMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyObjectTrumpMergePolicyType)

        insertSameIDObjectsInMainContext()
        
        dataStore.performClosureAndWait { [unowned self] context in
            do {
                let results = try context.findAllForEntityWithEntityName(self.entityName) as! [CreditCard]
                
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first!.cvv, self.cardTwoCVV)
            } catch let error {
                XCTFail("Fetch encountered error: \(error)")
            }
        }
    }
    
    func testOverwriteMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .OverwriteMergePolicyType)

        insertSameIDObjectsInMainContext()
        
        dataStore.performClosureAndWait { [unowned self] context in
            do {
                let results = try context.findAllForEntityWithEntityName(self.entityName) as! [CreditCard]
                
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first!.cvv, self.cardTwoCVV)
            } catch let error {
                XCTFail("Fetch encountered error: \(error)")
            }
        }
    }
    
    func testRollbackMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .RollbackMergePolicyType)

        insertSameIDObjectsInMainContext()
        
        dataStore.performClosureAndWait { [unowned self] context in
            do {
                let results = try context.findAllForEntityWithEntityName(self.entityName) as! [CreditCard]
                
                XCTAssertEqual(results.count, 1)
                XCTAssertEqual(results.first!.cvv, self.cardOneCVV)
            } catch let error {
                XCTFail("Fetch encountered error: \(error)")
            }
        }
    }
    
    // MARK: Async
    
    func testErrorMergePolicyAsync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .ErrorMergePolicyType)
        
        
    }
    
    func testMergeByPropertyStoreTrumpMergePolicyAsync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyStoreTrumpMergePolicyType)
        
    }
    
    func testMergeByPropertyObjectTrumpMergePolicyAsync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyObjectTrumpMergePolicyType)
        
    }
    
    func testOverwriteMergePolicyAsync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .OverwriteMergePolicyType)
        
    }
    
    func testRollbackMergePolicyAsync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .RollbackMergePolicyType)
        
    }
}
