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
        
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let card = object as! CreditCard
                    card.pan = "123"
                    card.cvv = 123
                    card.bank = "Chase"
                }
            })
            
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let card = object as! CreditCard
                    card.pan = "123"
                    card.cvv = 456
                    card.bank = "ANZ"
                }
            })
        } catch let error as NSError {
            XCTAssertNotNil(error.userInfo["conflictList"])
        }

//        dataStore.performClosureAndWait { [unowned self] context in
//            do {
//                let results = try context.findAllForEntityWithEntityName(self.entityName)
//
//                XCTAssertEqual(results.count, 1)
//                XCTAssertEqual(results.first!., <#T##expression2: [T : U]##[T : U]#>)
//            } catch let error {
//                XCTFail("Fetch encountered error: \(error)")
//            }
//        }
    }
    
    func testMergeByPropertyStoreTrumpMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyStoreTrumpMergePolicyType)

    }
    
    func testMergeByPropertyObjectTrumpMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .MergeByPropertyObjectTrumpMergePolicyType)

    }
    
    func testOverwriteMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .OverwriteMergePolicyType)

    }
    
    func testRollbackMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .RollbackMergePolicyType)

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
