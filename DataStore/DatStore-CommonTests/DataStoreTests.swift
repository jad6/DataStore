//
//  DataStoreTests.swift
//  DataStore
//
//  Created by Jad Osseiran on 13/11/2014.
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

import XCTest
import CoreData
import DataStore

class DataStoreTests: XCTestCase, DataStoreTestModel {
    
    var dataStore: DataStore!
    
    let defaultTimeout = 2.0
    
    let defaultHandler: XCWaitCompletionHandler = { error in
        XCTAssertNil(error)
    }
        
    override func setUp() {
        super.setUp()
        
        let model = DataStore.modelForResource("DataStoreTests", bundle: NSBundle(forClass: DataStoreTests.self))!
        do {
            dataStore = try DataStore(model: model,
                configuration: nil,
                storePath: nil,
                storeType: NSInMemoryStoreType,
                options: nil)
        } catch let error {
            assertionFailure("Could not create data store \(error)")
        }
    }
    
    override func tearDown() {
        do {
            try dataStore?.reset()
        } catch let error {
            assertionFailure("The Data Store must have been completely reset before rebuilding the stack for a new unit test \(error)")
        }

        dataStore = nil
        DataStore.clearCachedEntityNames()

        super.tearDown()
    }
}

protocol DataStoreTestModel {
    var dataStore: DataStore! { get set }
}

protocol DataStoreBaseTests: DataStoreTestModel {

    func testCreating()
    
    func testCreatingAndSave()
    
    func testCreatingAndWait()
    
    func testCreatingWaitAndSave()
    
    func testFetchingExistingSync()
    
    func testFetchingNonExistingSync()
    
    func testFetchingWithValueAndKeySync()
    
    func testFetchingWithOrderSync()
        
    func testFetchingExistingAsync()
    
    func testFetchingNonExistingAsync()
    
    func testFetchingWithValueAndKeyAsync()
    
    func testFetchingWithOrderAsync()
}

protocol DataStoreUniqunessTests: DataStoreTestModel {

    func testErrorMergePolicySync()

    func testMergeByPropertyStoreTrumpMergePolicySync()

    func testMergeByPropertyObjectTrumpMergePolicySync()

    func testOverwriteMergePolicySync()

    func testRollbackMergePolicySync()

    func testErrorMergePolicyAsync()

    func testMergeByPropertyStoreTrumpMergePolicyAsync()

    func testMergeByPropertyObjectTrumpMergePolicyAsync()

    func testOverwriteMergePolicyAsync()

    func testRollbackMergePolicyAsync()
}

extension DataStoreBaseTests {
    var entityName: String {
        var personEntityName: String!
        do {
            personEntityName = try dataStore?.entityNameForObjectClass(Person.self)
        } catch let error {
            XCTFail("Failed to fetch entity name with error \(error)")
            assertionFailure("I'm doing you a favour by crashing here.")
        }
        return personEntityName
    }
}

extension DataStoreUniqunessTests {
    var entityName: String {
        var cardEntityName: String!
        do {
            cardEntityName = try dataStore?.entityNameForObjectClass(CreditCard.self)
        } catch let error {
            XCTFail("Failed to fetch entity name with error \(error)")
            assertionFailure("I'm doing you a favour by crashing here.")
        }
        return cardEntityName
    }
}
