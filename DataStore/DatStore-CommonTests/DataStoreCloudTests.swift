//
//  DataStoreCloudTests.swift
//  DataStore
//
//  Created by Jad Osseiran on 24/11/2014.
//  Copyright (c) 2015 Jad Osseiran. All rights reserved.
//

import XCTest
import CoreData
import DataStore

class DataStoreCloudTests: DataStoreTests {

    override func setUp() {
        
//        delegateObject = self
        
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }

    func testExample() {
        // This is an example of a functional test case.
        XCTAssert(true, "Pass")
    }

    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measureBlock() {
            // Put the code you want to measure the time of here.
        }
    }

}
