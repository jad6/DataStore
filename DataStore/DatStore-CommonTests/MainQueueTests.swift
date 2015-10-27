//
//  MainQueueTests.swift
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

class MainQueueTests: DataStoreTests, DataStoreBaseTests {
    
    override func setUp() {
        super.setUp()
    }
    
    override func tearDown() {
        super.tearDown()
    }
    
    // MARK: Creating
    
    func testCreating() {
        let expectation = expectationWithDescription("Inserted")
        
        let personEntityName = entityName
        dataStore.performClosure() { context in
            var insertedPerson: Person?
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }

            XCTAssertEqual(insertedPerson?.firstName, "Jad")
            XCTAssertEqual(insertedPerson?.lastName, "Osseiran")
            XCTAssertTrue(context.hasChanges)
            
            expectation.fulfill()
        }
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testCreatingAndSave() {
        let expectation = expectationWithDescription("Inserted and save")
        
        let personEntityName = entityName
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            XCTAssertFalse(context.hasChanges)
            XCTAssertNil(error)
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testCreatingAndWait() {
        var insertedPerson: Person?
        dataStore.performClosureAndWait() { [unowned self] context in
            context.insertObjectWithEntityName(self.entityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
                
                insertedPerson = person
            }
        }
        
        XCTAssertEqual(insertedPerson?.firstName, "Jad")
        XCTAssertEqual(insertedPerson?.lastName, "Osseiran")
        XCTAssertTrue(dataStore.mainManagedObjectContext.hasChanges)
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
            XCTFail("The save was unsuccessful \(error)")
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
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
        
        var person: Person!
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]

                XCTAssertEqual(results.count, 1)
                person = results.last!
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
        }
        
        XCTAssertEqual(person.firstName, "Jad")
        XCTAssertEqual(person.lastName, "Osseiran")
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
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
        
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let predicate = NSPredicate(format: "firstName == \"Nils\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]

                XCTAssertEqual(results.count, 0)
            } catch let error {
                XCTFail("Fetch failed \(error)")
            }
        }
        
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
    }
    
    func testFetchingWithValueAndKeySync() {
        do {
            try dataStore.performClosureWaitAndSave({ [unowned self] context in
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
                    XCTFail("Fetch failed \(error)")
                    results = nil
                }
                XCTAssertNotNil(results)
                XCTAssertEqual(results!.count, 1)
            })
        } catch let error {
            XCTFail("Save failed \(error)")
        }

        var person: Person!
        dataStore.performClosureAndWait() { [unowned self] context in
            do {
                let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(self.entityName, withPredicate: predicate) as! [Person]

                XCTAssertEqual(results.count, 1)
                person = results.last
            } catch let error {
                XCTFail("Fetch failed \(error)")
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
                for i in 0 ..< smallNumber {
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
                XCTFail("Fetch failed \(error)")
            }
        }
        
        XCTAssertEqual("9876543210", fetchedConcatinatedFirstNameString)
        XCTAssertFalse(dataStore.mainManagedObjectContext.hasChanges)
    }
    
    // MARK: Asynchrnous Tests
    
    func testFetchingExistingAsync() {
        let expectation = expectationWithDescription("Fetch existing")
        
        let personEntityName = entityName
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            XCTAssertNil(error)
            do {
                let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                XCTAssertEqual(results.count, 1, "Only one person was inserted")
                
                let person = results.last!
                XCTAssertEqual(person.firstName, "Jad")
                XCTAssertEqual(person.lastName, "Osseiran")
                XCTAssertFalse(context.hasChanges)
            } catch let fetchError {
                XCTFail("Fetch failed \(fetchError)")
            }
            
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingNonExistingAsync() {
        let expectation = expectationWithDescription("Fetch Non-existing")

        let personEntityName = entityName
        dataStore.performClosureAndSave({ context in
            context.insertObjectWithEntityName(personEntityName) { object in
                let person = object as! Person
                person.firstName = "Jad"
                person.lastName = "Osseiran"
            }
        }, completion: { context, error in
            XCTAssertNil(error)
            do {
                let predicate = NSPredicate(format: "firstName == \"Nils\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                
                XCTAssertEqual(results.count, 0)
                XCTAssertFalse(context.hasChanges)
            } catch let fetchError {
                XCTFail("Fetch failed \(fetchError)")
            }
            
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingWithValueAndKeyAsync() {
        let expectation = expectationWithDescription("Fetch existing key-value")

        let personEntityName = entityName
        dataStore.performClosureAndSave({ context in
            do {
                try context.findOrInsertEntitiesWithEntityName(personEntityName, whereKey: "firstName", equalsValue: "Jad") { insertedObject, inserted in
                    let person = insertedObject as? Person
                    person?.firstName = "Jad"
                    person?.lastName = "Osseiran"
                    XCTAssertTrue(inserted)
                }
            } catch let error {
                XCTFail("Insertion failed \(error)")
            }
        }, completion: { context, error in
            XCTAssertNil(error)
            
            do {
                let predicate = NSPredicate(format: "firstName == \"Jad\" AND lastName == \"Osseiran\"")
                let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: predicate) as! [Person]
                XCTAssertEqual(results.count, 1, "Only one person was inserted")
                
                let person = results.last!
                XCTAssertEqual(person.firstName, "Jad")
                XCTAssertEqual(person.lastName, "Osseiran")
                XCTAssertFalse(context.hasChanges)
            } catch let fetchError {
                XCTFail("Fetch failed \(fetchError)")
            }
            
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
    
    func testFetchingWithOrderAsync() {
        let expectation = expectationWithDescription("Fetch in order")
        let smallNumber = 10
        
        let personEntityName = entityName
        dataStore.performClosureAndSave({ context in
            for i in 0 ..< smallNumber {
                context.insertObjectWithEntityName(personEntityName) { object in
                    let person = object as! Person
                    person.firstName = "\(i)"
                    person.lastName = "\(i*2)"
                }
            }
        }, completion: { context, error in
            XCTAssertNil(error)
            
            do {
                let sortDescriptor = NSSortDescriptor(key: "firstName", ascending: false)
                let results = try context.findEntitiesForEntityName(personEntityName, withPredicate: nil, andSortDescriptors: [sortDescriptor]) as! [Person]
                
                var fetchedConcatinatedFirstNameString = String()
                for person in results {
                    fetchedConcatinatedFirstNameString += person.firstName!
                }
                
                XCTAssertEqual(results.count, smallNumber)
                XCTAssertEqual("9876543210", fetchedConcatinatedFirstNameString)
                XCTAssertFalse(context.hasChanges)
            } catch let fetchError {
                XCTFail("Fetch failed \(fetchError)")
            }
            
            expectation.fulfill()
        })
        
        waitForExpectationsWithTimeout(defaultTimeout, handler: defaultHandler)
    }
}
