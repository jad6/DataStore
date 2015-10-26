//
//  Person+CoreDataProperties.swift
//  DataStore
//
//  Created by Jad Osseiran on 10/25/15.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//
//  Choose "Create NSManagedObject Subclass…" from the Core Data editor menu
//  to delete and recreate this implementation file for your updated model.
//

import Foundation
import CoreData

extension Person {

    @NSManaged var firstName: String?
    @NSManaged var lastName: String?
    @NSManaged var creditCards: NSSet?

}
