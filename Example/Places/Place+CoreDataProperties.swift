//
//  Place+CoreDataProperties.swift
//  Places
//
//  Created by Jad Osseiran on 20/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//
//  Delete this file and regenerate it using "Create NSManagedObject Subclass…"
//  to keep your implementation up to date with your model.
//

import Foundation
import CoreData

extension Place {

    @NSManaged var name: String?
    @NSManaged var datCreated: NSDate?

}
