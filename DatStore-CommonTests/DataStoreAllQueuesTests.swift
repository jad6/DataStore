//
//  DataStoreAllQueuesTests.swift
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

class DataStoreAllQueuesTests: DataStoreTests, DataStoreOperationTests {

    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }

    // MARK: - Creating
    
    func testCreating() {
        let expectation = expectationWithDescription("Inserted")
        
        var insertedPerson: DSTPerson?
        var insertedBackgroundPerson: DSTPerson?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosure() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosure() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
                
                insertedBackgroundPerson = person
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            XCTAssert(insertedPerson?.firstName == "Jad" &&
                insertedPerson?.lastName == "Osseiran" &&
                insertedBackgroundPerson?.firstName == "Nils" &&
                insertedBackgroundPerson?.lastName == "Osseiran" &&
                self.dataStore.mainManagedObjectContext.hasChanges &&
                self.dataStore.backgroundManagedObjectContext.hasChanges, "Pass")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testCreatingAndSave() {
        let expectation = expectationWithDescription("Inserted and save")
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            XCTAssert(self.dataStore.mainManagedObjectContext.hasChanges == false &&
                self.dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testCreatingAndWait() {
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var insertedPerson: DSTPerson?
        var insertedBackgroundPerson: DSTPerson?
        
        dataStore.performClosureAndWait() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
        }
        
        dataStore.performBackgroundClosureAndWait() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
                
                insertedBackgroundPerson = person
            }
        }
        
        XCTAssert(insertedPerson?.firstName == "Jad" &&
            insertedPerson?.lastName == "Osseiran" &&
            insertedBackgroundPerson?.firstName == "Nils" &&
            insertedBackgroundPerson?.lastName == "Osseiran" &&
            dataStore.mainManagedObjectContext.hasChanges &&
            dataStore.backgroundManagedObjectContext.hasChanges, "Pass")
    }
    
    func testCreatingWaitAndSave() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        dataStore.performBackgroundClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        XCTAssert(error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false &&
            dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
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
        dataStore.performBackgroundClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
        
        dataStore.performClosureAndWait() { context in
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 2 {
                XCTFail("Only two people were inserted")
            }
        }
        
        XCTAssert(error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false &&
            dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
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
        dataStore.performBackgroundClosureWaitAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, error: &error)
        
        let predicate = NSPredicate(format: "lastName == \"Wood\"")
        
        dataStore.performClosureAndWait() { context in
            let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
            if results.count != 0 {
                XCTFail("No match should have been found.")
            }
        }
        
        XCTAssert(error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false &&
            dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
    }
    
    func testFetchingWithValueAndKeySync() {
        var error: NSError?
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var success = dataStore.performClosureWaitAndSave({ context in
            let results = context.findEntitiesWithEntityName(entityName,
                wherKey: "firstName",
                equalsValue: "Jad",
                error: &error) { insertedObject in
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
            }
            if results?.count != 1 {
                XCTFail("No matches should exist")
            }
        }, error: &error)
        
        if success == false {
            XCTFail("No success for you!")
        }
        
        success = dataStore.performClosureWaitAndSave({ context in
            let results = context.findEntitiesWithEntityName(entityName,
                wherKey: "firstName",
                equalsValue: "Jad",
                error: &error) { insertedObject in
                    XCTFail("This closure should not enter as! the object has already been created and saved on the other context.")
                    
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
            }
            if results?.count != 1 {
                XCTFail("No matches should exist")
            }
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
            
            for i in 0 ..< (smallNumber / 2) {
                context.insertObjectWithEntityName(entityName) { object in
                    let person = object as! DSTPerson
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, error: &error)
        
        dataStore.performBackgroundClosureWaitAndSave({ context in
            let entityName = self.dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
            
            for i in (smallNumber / 2) ..< smallNumber {
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
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
                
                var error: NSError?
                let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
                if results.count != 2 {
                    XCTFail("Only two people were inserted")
                }
                
                XCTAssert(error == nil && context.hasChanges == false, "Pass")
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingNonExistingAsync() {
        let expectation = expectationWithDescription("Fetch Non-existing")
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                let predicate = NSPredicate(format: "firstName == \"Nathan\" AND lastName == \"Wood\"")
                
                var error: NSError?
                let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
                
                XCTAssert(results.count == 0 && error == nil && context.hasChanges == false, "Pass")
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingWithValueAndKeyAsync() {
        let expectation = expectationWithDescription("Fetch existing key-value")
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")

        var group = dispatch_group_create()

        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            var error: NSError?
            context.findEntitiesWithEntityName(entityName,
                wherKey: "firstName",
                equalsValue: "Jad",
                error: &error) { insertedObject in
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })

        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            var error: NSError?
            context.findEntitiesWithEntityName(entityName,
                wherKey: "firstName",
                equalsValue: "Nils",
                error: &error) { insertedObject in
                    let person = insertedObject as? DSTPerson
                    person?.firstName = "Nils"
                    person?.lastName = "Osseiran"
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })

        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
                
                var error: NSError?
                let results = context.findEntitiesForEntityName(entityName, withPredicate: predicate, error: &error) as! [DSTPerson]
                if results.count != 2 {
                    XCTFail("Only two people were inserted")
                }
                
                XCTAssert(error == nil && context.hasChanges == false, "Pass")
                expectation.fulfill()
            }
        }
    
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    func testFetchingWithOrderAsync() {
        let expectation = expectationWithDescription("Fetch in order")
        let smallNumber = 10
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            for i in 0 ..< (smallNumber / 2) {
                context.insertObjectWithEntityName(entityName) { object in
                    let person = object as! DSTPerson
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, completion: { context, error in
            dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            for i in (smallNumber / 2) ..< smallNumber {
                context.insertObjectWithEntityName(entityName) { object in
                    let person = object as! DSTPerson
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
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
            }
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
    
    // MARK: - Parallel Saving
    
    func testCreatingOnMultipleContextsAndSaveSync() {
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        dataStore.performClosureAndWait() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }
        
        dataStore.performBackgroundClosureAndWait() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }
        
        var error: NSError?
        let success = dataStore.saveAndWait(onContextSave: { context in
            // FIXME: This strangely calls save:completion:... I have no clue as! to why?!
            XCTAssertFalse(context.hasChanges, "The context should not have changes")
        }, error: &error)
        
        dataStore.performClosureAndWait() { context in
            var fetchError: NSError?
            let results = context.findAllForEntityWithEntityName(entityName, error: &fetchError)
            if results?.count != 2 || fetchError != nil {
                XCTFail("Save failed")
            }
        }
        
        XCTAssert(success && error == nil &&
            dataStore.mainManagedObjectContext.hasChanges == false &&
            dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
    }
    
    func testCreatingOnMultipleContextsAndSaveAsync() {
        let expectation = expectationWithDescription("Create parallel and save")
        
        let entityName = dataStore.entityNameForObjectClass(DSTPerson.self, withClassPrefix: "DST")
        
        var group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosure() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosure() { context in
            context.insertObjectWithEntityName(entityName) { object in
                let person = object as! DSTPerson
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.save(onContextSave: { context in
                // FIXME: This strangely calls saveAndWait:... I have no clue as! to why?!
                XCTAssertFalse(context.hasChanges, "The context should not have changes")
            }, completion: { error in
                self.dataStore.performClosureAndWait() { context in
                    var fetchError: NSError?
                    let results = context.findAllForEntityWithEntityName(entityName, error: &fetchError)
                    if results?.count != 2 || fetchError != nil {
                        XCTFail("Save failed")
                    }
                }
                
                XCTAssert(error == nil &&
                    self.dataStore.mainManagedObjectContext.hasChanges == false &&
                    self.dataStore.backgroundManagedObjectContext.hasChanges == false, "Pass")
                expectation.fulfill()
            })
        }
        
        waitForExpectationsWithTimeout(2.0, handler: nil)
    }
}
