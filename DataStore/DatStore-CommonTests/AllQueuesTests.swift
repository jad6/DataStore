//
//  AllQueuesTests.swift
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

import XCTest
import CoreData
import DataStore

class AllQueuesTests: DataStoreTests, DataStoreBaseTests {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: Creating
    
    func testCreating() {
        let expectation = expectationWithDescription("Inserted")
        
        var insertedPerson: Person?
        var insertedBackgroundPerson: Person?

        let personEntityName = entityName
        let group = dispatch_group_create()

        dispatch_group_enter(group)
        dataStore.performClosure() { context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosure() { context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
                
                insertedBackgroundPerson = person
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) { [weak self] in
            XCTAssertEqual(insertedPerson?.firstName, "Jad")
            XCTAssertEqual(insertedPerson?.lastName, "Osseiran")
            XCTAssertEqual(insertedBackgroundPerson?.firstName, "Nils")
            XCTAssertEqual(insertedBackgroundPerson?.lastName, "Osseiran")
            
            if let weakSelf = self {
                XCTAssertTrue(weakSelf.dataStore.mainManagedObjectContext.hasChanges)
                XCTAssertTrue(weakSelf.dataStore.backgroundManagedObjectContext.hasChanges)
            } else {
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testCreatingAndSave() {
        let expectation = expectationWithDescription("Inserted and save")
        
        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) { [weak self] in
            if let weakSelf = self {
                XCTAssertFalse(weakSelf.dataStore.mainManagedObjectContext.hasChanges)
                XCTAssertFalse(weakSelf.dataStore.backgroundManagedObjectContext.hasChanges)
            } else {
                XCTFail()
            }
            
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testCreatingAndWait() {
        var insertedPerson: Person?
        var insertedBackgroundPerson: Person?

        dataStore.performClosureAndWait() { [unowned self] context in
            context.insertObjectWithEntityName(self.entityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
        }
        
        dataStore.performBackgroundClosureAndWait() { [unowned self] context in
            context.insertObjectWithEntityName(self.entityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
                
                insertedBackgroundPerson = person
            }
        }
        
        XCTAssertEqual(insertedPerson?.firstName, "Jad")
        XCTAssertEqual(insertedPerson?.lastName, "Osseiran")
        XCTAssertEqual(insertedBackgroundPerson?.firstName, "Nils")
        XCTAssertEqual(insertedBackgroundPerson?.lastName, "Osseiran")
        XCTAssertTrue(dataStore.mainManagedObjectContext.hasChanges)
        XCTAssertTrue(dataStore.backgroundManagedObjectContext.hasChanges)
    }
    
    func testCreatingWaitAndSave() {
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Jad"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        do {
            try dataStore.performBackgroundClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Nils"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
        XCTAssertFalse(dataStore.backgroundManagedObjectContext.hasChanges)
    }
    
    // MARK: Synchrnous Tests
    
    func testFetchingExistingSync() {
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Jad"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        do {
            try dataStore.performBackgroundClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Nils"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
        
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]
                XCTAssertEqual(2, results.count, "Only two people should be inserted")
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
        XCTAssertFalse(dataStore.backgroundManagedObjectContext.hasChanges)
    }
    
    func testFetchingNonExistingSync() {
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Jad"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        do {
            try dataStore.performBackgroundClosureWaitAndSave({ [unowned self] context in
                context.insertObjectWithEntityName(self.entityName) { object in
                    let person = object as! Person
                    person.firstName = "Nils"
                    person.lastName = "Osseiran"
                }
            })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        let predicate = NSPredicate(format: "lastName == \"Wood\"")
        
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]
                XCTAssertEqual(results.count, 0, "No match should have been found.")
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
        XCTAssertFalse(dataStore.backgroundManagedObjectContext.hasChanges)
    }
    
    func testFetchingWithValueAndKeySync() {
        do {
            try dataStore.performClosureWaitAndSave { [unowned self] context in
                let results: [AnyObject]?
                do {
                    results = try context.findOrInsertEntitiesWithEntityName(self.entityName,
                        whereKey: "firstName",
                        equalsValue: "Jad") { insertedObject, inserted in
                            let person = insertedObject as? Person
                            person?.firstName = "Jad"
                            person?.lastName = "Osseiran"
                            XCTAssertTrue(inserted)
                    }
                } catch let error {
                    XCTFail("Insertion failed \(error)")
                    results = nil
                }
                
                if let unwrappedResults = results {
                    XCTAssertEqual(unwrappedResults.count, 1)
                }
            }
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        do {
            try dataStore.performClosureWaitAndSave{ [unowned self] context in
                let results: [AnyObject]?
                do {
                    results = try context.findOrInsertEntitiesWithEntityName(self.entityName,
                        whereKey: "firstName",
                        equalsValue: "Jad") { insertedObject, inserted in
                            let person = insertedObject as? Person
                            person?.firstName = "Jad"
                            person?.lastName = "Osseiran"
                            XCTAssertFalse(inserted)
                    }
                } catch let error {
                    XCTFail("Insertion failed \(error)")
                    results = nil
                }
                if let unwrappedResults = results {
                    XCTAssertEqual(unwrappedResults.count, 1)
                }
            }
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        var person: Person!
        dataStore.performClosureAndWait() { [unowned self] context in
            let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
            
            do {
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]
                
                XCTAssertEqual(results.count, 1)
                person = results.last
            } catch let error {
                XCTFail("Insertion failed \(error)")
            }
        }
        
        XCTAssertEqual(person.firstName, "Jad")
        XCTAssertEqual(person.lastName, "Osseiran")
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
    }
    
    func testFetchingWithOrderSync() {
        let smallNumber = 10
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
                for i in 0 ..< (smallNumber / 2) {
                    context.insertObjectWithEntityName(self.entityName) { object in
                        let person = object as! Person
                        person.firstName = "\(i)"
                        person.lastName = "\(i*2)"
                    }
                }
                })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        do {
            try dataStore.performBackgroundClosureWaitAndSave({ [unowned self] context in
                for i in (smallNumber / 2) ..< smallNumber {
                    context.insertObjectWithEntityName(self.entityName) { object in
                        let person = object as! Person
                        person.firstName = "\(i)"
                        person.lastName = "\(i*2)"
                    }
                }
                })
        } catch let error {
            XCTFail("Insertion failed \(error)")
        }
        
        var fetchedConcatinatedFirstNameString = String()
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let sortDescriptor = NSSortDescriptor(key: "firstName", ascending: false)
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: nil, andSortDescriptors: [sortDescriptor]) as! [Person]
                
                XCTAssertEqual(results.count, smallNumber, "The count does not match")
                
                for person in results {
                    fetchedConcatinatedFirstNameString += person.firstName!
                }
            } catch let error {
                XCTFail("Insertion failed \(error)")
            }
        }
        
        XCTAssertEqual("9876543210", fetchedConcatinatedFirstNameString)
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
    }
    
    // MARK: Asynchrnous Tests
    
    func testFetchingExistingAsync() {
        let expectation = expectationWithDescription("Fetch existing")
        
        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
                
                do {
                    let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                    XCTAssertEqual(results.count, 2, "Only two people were inserted")
                } catch let error {
                    XCTFail("Fetch failed \(error)")
                }
                
                XCTAssertFalse(context.hasChanges)
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingNonExistingAsync() {
        let expectation = expectationWithDescription("Fetch Non-existing")
        
        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                let predicate = NSPredicate(format: "firstName == \"Nathan\" AND lastName == \"Wood\"")
                
                do {
                    let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                    XCTAssertEqual(results.count, 0)
                } catch let error {
                    XCTFail("Fetch failed \(error)")
                }
                
                XCTAssertFalse(context.hasChanges)
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingWithValueAndKeyAsync() {
        let expectation = expectationWithDescription("Fetch existing key-value")

        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            do {
                try context.findOrInsertEntitiesWithEntityName(personEntityName, whereKey: "firstName", equalsValue: "Jad") { insertedObject, inserted in
                        let person = insertedObject as? Person
                        person?.firstName = "Jad"
                        person?.lastName = "Osseiran"
                        XCTAssertTrue(inserted)
                }
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosureAndSave({ context in
            do {
                try context.findOrInsertEntitiesWithEntityName(personEntityName, whereKey: "firstName", equalsValue: "Nils") { insertedObject, inserted in
                        let person = insertedObject as? Person
                        person?.firstName = "Nils"
                        person?.lastName = "Osseiran"
                        XCTAssertTrue(inserted)
                }
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
            }, completion: { context, error in
                dispatch_group_leave(group)
        })
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.performClosureAndWait() { context in
                do {
                    let predicate = NSPredicate(format: "lastName == \"Osseiran\"")
                    let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                    XCTAssertEqual(results.count, 2, "Only two people were inserted")
                } catch let error {
                    XCTFail("Fetch failed \(error)")
                }
                
                XCTAssertFalse(context.hasChanges)
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingWithOrderAsync() {
        let expectation = expectationWithDescription("Fetch in order")
        let smallNumber = 10

        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosureAndSave({ context in
            for i in 0 ..< (smallNumber / 2) {
                context.insertObjectWithEntityName(personEntityName) { object in
                    let person = object as! Person
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
                context.insertObjectWithEntityName(personEntityName) { object in
                    let person = object as! Person
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
                
                do {
                    let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: nil, andSortDescriptors: [sortDescriptor]) as! [Person]

                    var fetchedConcatinatedFirstNameString = String()
                    for person in results {
                        fetchedConcatinatedFirstNameString += person.firstName!
                    }
                    
                    XCTAssertEqual(results.count, smallNumber)
                    XCTAssertEqual("9876543210", fetchedConcatinatedFirstNameString)
                } catch let error {
                    XCTFail("Fetch failed \(error)")
                }
                
                XCTAssertFalse(context.hasChanges)
                expectation.fulfill()
            }
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    // MARK: Parallel Saving
    
    func testCreatingOnMultipleContextsAndSaveSync() {
        dataStore.performClosureAndWait() { [unowned self] context in
            context.insertObjectWithEntityName(self.entityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }
        
        dataStore.performBackgroundClosureAndWait() { [unowned self] context in
            context.insertObjectWithEntityName(self.entityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
        }
        
        do {
            try dataStore.saveAndWait(onContextSave: { context in
                // FIXME: This strangely calls save:completion:... I have no clue as! to why?!
                XCTAssertFalse(context.hasChanges, "The context should not have changes")
            })
        } catch let error {
            XCTFail("Failed to save \(error)")
        }
        
        dataStore.performClosureAndWait() { [unowned self] context in
            let results: [AnyObject]?
            do {
                results = try context.findAllForEntityWithEntityName(self.entityName)
            } catch let error {
                XCTFail("Fetch failed \(error)")
                results = nil
            }
            
            if let unwrappedResults = results {
                XCTAssertEqual(2, unwrappedResults.count)
            }
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
        XCTAssertFalse(dataStore.backgroundManagedObjectContext.hasChanges)
    }
    
    func testCreatingOnMultipleContextsAndSaveAsync() {
        let expectation = expectationWithDescription("Create parallel and save")
        
        let personEntityName = entityName
        let group = dispatch_group_create()
        
        dispatch_group_enter(group)
        dataStore.performClosure() { context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_enter(group)
        dataStore.performBackgroundClosure() { context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Nils"
                person.lastName = "Osseiran"
            }
            dispatch_group_leave(group)
        }
        
        dispatch_group_notify(group, dispatch_get_main_queue()) {
            self.dataStore.save(onContextSave: { context in
                // FIXME: This strangely calls saveAndWait:... I have no clue as! to why?!
                XCTAssertFalse(context.hasChanges, "The context should not have changes")
                }, completion: { [weak self] error in
                    guard self != nil else {
                        XCTFail()
                        return
                    }
                    
                    self!.dataStore.performClosureAndWait() { context in
                        let results: [AnyObject]?
                        do {
                            results = try context.findAllForEntityWithEntityName(personEntityName)
                        } catch let error {
                            XCTFail("Fetch failed \(error)")
                            results = nil
                        }
                        
                        if let unwrappedResults = results {
                            XCTAssertEqual(2, unwrappedResults.count)
                        }
                    }
                    
                    XCTAssertNil(error)
                    XCTAssertFalse(self!.dataStore.mainManagedObjectContext.hasChanges)
                    XCTAssertFalse(self!.dataStore.backgroundManagedObjectContext.hasChanges)
                    
                    expectation.fulfill()
            })
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
}
