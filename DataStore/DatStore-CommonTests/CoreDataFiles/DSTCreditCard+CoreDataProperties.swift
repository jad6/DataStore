//
//  DSTCreditCard+CoreDataProperties.swift
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

extension DSTCreditCard {

    @NSManaged var pan: String?
    @NSManaged var cvv: NSNumber?
    @NSManaged var bank: String?
    @NSManaged var holder: DSTPerson?

}
