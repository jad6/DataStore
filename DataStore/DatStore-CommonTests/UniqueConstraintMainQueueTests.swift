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

class UniqueConstraintTests: DataStoreTests {
    
    // MARK: Sync
    
    func testErrorMergePolicySync() {
        dataStore.mergePolicy = NSMergePolicy(mergeType: .ErrorMergePolicyType)
        
        let entityName = dataStore.entityNameForObjectClass(DSTCreditCard.self, withClassPrefix: "DST")
        do {
            try dataStore.performClosureWaitAndSave({ context in
                context.insertObjectWithEntityName(entityName) { object in
                    let card = object as! DSTCreditCard
                    card.pan = "123"
                    card.cvv = 123
                    card.bank = "Chase"
                }
            })
            
            try dataStore.performClosureWaitAndSave({ context in
                context.insertObjectWithEntityName(entityName) { object in
                    let card = object as! DSTCreditCard
                    card.pan = "123"
                    card.cvv = 456
                    card.bank = "ANZ"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
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
