//
//  DataStoreMainQueueTests.swift
//  DataStore
//
//  Created by Jad Osseiran on 17/11/2014.
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

import XCTest
import CoreData
import DataStore

class DataStoreMainQueueTests: DataStoreTests, DataStoreOperationTests {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: - Creating
    
    func testCreating() {
        let expectation = expectationWithDescription("Inserted")
        
        dataStore.performClosure() { context in
            var insertedPerson: DSTPerson?
            
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }

            XCTAssert(insertedPerson?.firstName == "Jad" &&
                insertedPerson?.lastName == "Osseiran" && context.hasChanges, "Pass")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testCreatingAndSave() {
        let expectation = expectationWithDescription("Inserted and save")
        
        dataStore.performClosureAndSave({ context in
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            XCTAssert(context.hasChanges == false && error == nil, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testCreatingAndWait() {
        var insertedPerson: DSTPerson?
        dataStore.performClosureAndWait() { context in
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
        }
        
        XCTAssert(insertedPerson?.firstName == "Jad" &&
            insertedPerson?.lastName == "Osseiran" &&
            dataStore.mainManagedObjectContext.hasChanges, "Pass")
    }
    
    func testCreatingWaitAndSave() {
        var error: NSError?
        
        dataStore.performClosureWaitAndSave({ context in
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        XCTAssert(error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false, "Pass")
    }
    
    // MARK: - Synchrnous Tests
    
    func testFetchingExistingSync() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        var person: DSTPerson!
        dataStore.performClosureAndWait() { context in
            let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
            
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 1 {
                XCTFail("Only one person was inserted")
            }
            
            person = results.last!
        }
        
        XCTAssert(person.firstName == "Jad" &&
            person.lastName == "Osseiran" && error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false, "Pass")
    }
    
    func testFetchingNonExistingSync() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        dataStore.performClosureAndWait() { context in
            let predicate = NSPredicate(format: "firstName == \"Nils\" AND lastName == \"Osseiran\"")
            
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            
            if results.count != 0 {
                XCTFail("There should be no matches")
            }
        }
        
        XCTAssert(error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false, "Pass")
    }
    
    func testFetchingWithValueAndKeySync() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        let success = dataStore.performClosureWaitAndSave({ context in
            let results = context.findOrInsertEntitiesWithEntityName(entityName,
                whereKey: "firstName",
                equalsValue: "Jad",
                error: &error) { insertedObject, inserted in
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
                    XCTAssertTrue(inserted)
            }
            XCTAssertNotNil(results)
            XCTAssertEqual(results!.count, 1)
        }, error: &error)
        
        var person: DSTPerson!
        dataStore.performClosureAndWait() { context in
            let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
            
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 1 {
                XCTFail("Only one person was inserted")
            }

            person = results.last
        }
        
        XCTAssert(person.firstName == "Jad" &&
            person.lastName == "Osseiran" &&
            error == nil && success &&
            dataStore.mainManagedObjectContext.hasChanges == false, "Pass")
    }
    
    func testFetchingWithOrderSync() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        let smallNumber = 10
        
        dataStore.performClosureWaitAndSave({ context in
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            for i in 0 ..< smallNumber {
                context.insertObjectWithEntityName(entityName) { object in
                    let person = object as! DSTPerson
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, error: &error)
        
        var fetchedConcatinatedFirstNameString = String()
        dataStore.performClosureAndWait() { context in
            let sortDescriptor = NSSortDescriptor(key: "firstName", ascending: false)
            let results = context.findEntitiesForEntityName(entityName, withPredicate: nil, andSortDescriptors: [sortDescriptor], error: &error) as! [DSTPerson]
            
            if results.count != smallNumber {
                XCTFail("The count does not match")
            }
            
            for person in results {
                fetchedConcatinatedFirstNameString += person.firstName
            }
        }
        
        let desiredConcatinatedFirstNameString = "9876543210"
        
        XCTAssert(error == nil &&
            desiredConcatinatedFirstNameString == fetchedConcatinatedFirstNameString &&
            dataStore.mainManagedObjectContext.hasChanges == false, "Pass")
    }
    
    // MARK: - Asynchrnous Tests
    
    func testFetchingExistingAsync() {
        let expectation = expectationWithDescription("Fetch existing")
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
            
            var error: NSError?
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 1 {
                XCTFail("Only one person was inserted")
            }
            
            let person = results.last!
            
            XCTAssert(person.firstName == "Jad" &&
                person.lastName == "Osseiran" &&
                error == nil && context.hasChanges == false, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingNonExistingAsync() {
        let expectation = expectationWithDescription("Fetch Non-existing")
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            let predicate = NSPredicate(format: "firstName == \"Nils\" AND lastName == \"Osseiran\"")
            
            var error: NSError?
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            
            XCTAssert(results.count == 0 && error == nil && context.hasChanges == false, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingWithValueAndKeyAsync() {
        let expectation = expectationWithDescription("Fetch existing key-value")
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureAndSave({ context in
            var error: NSError?
            context.findOrInsertEntitiesWithEntityName(entityName,
                whereKey: "firstName",
                equalsValue: "Jad",
                error: &error) { insertedObject, inserted in
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
                    XCTAssertTrue(inserted)
            }
        }, completion: { context, error in
            let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
            
            var error: NSError?
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 1 {
                XCTFail("Only one person was inserted")
            }
            
            let person = results.last!
            
            XCTAssert(person.firstName == "Jad" &&
                person.lastName == "Osseiran" &&
                error == nil && context.hasChanges == false, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingWithOrderAsync() {
        let expectation = expectationWithDescription("Fetch in order")
        let smallNumber = 10
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureAndSave({ context in
            for i in 0 ..< smallNumber {
                context.insertObjectWithEntityName(entityName) { object in
                    let person = object as! DSTPerson
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, completion: { context, error in
            let sortDescriptor = NSSortDescriptor(key: "firstName", ascending: false)
            var error: NSError?
            
            let results = context.findEntitiesForEntityName(entityName, withPredicate: nil, andSortDescriptors: [sortDescriptor], error: &error) as! [DSTPerson]
            
            let desiredConcatinatedFirstNameString = "9876543210"
            
            var fetchedConcatinatedFirstNameString = String()
            for person in results {
                fetchedConcatinatedFirstNameString += person.firstName
            }
            
            XCTAssert(results.count == smallNumber && error == nil &&
                desiredConcatinatedFirstNameString == fetchedConcatinatedFirstNameString &&
                context.hasChanges == false, "Pass")
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
}
