//
//  DataStoreErrors.swift
//  DataStore
//
//  Created by Jad Osseiran on 20/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
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

import Foundation

let errorDomain = "com.jadosseiran.DataStore.errors"
let entitiesFialedKey = "entitiesFialed"

public enum DataStoreError: ErrorType {
    /// The object to delete is invalid, most likely not a `NSManagedObject` instance.
    case InvalidDeleteObject
    /// The entity for the object to delete is invalid.
    case FailedEntityDeletion
    /// A non `NSManagedObject` was attempted to be deleted.
    case DeleteNonManagedObject
    /// A closure captured symbol tried to reference a deallocated object.
    case PrematureDeallocation
}

extension NSError {
    class var prematureDeallocationError: NSError {
        let userInfo: [String: AnyObject] = [NSLocalizedDescriptionKey: "A symbol that was captured by a closure no longer exists, logic related to it is ignored.", NSLocalizedRecoveryOptionsErrorKey: "Check the closures related to this error's stack trace."]
        return NSError(domain: errorDomain, code: DataStoreError.PrematureDeallocation._code, userInfo: userInfo)
    }
    
    class func failedDeletionErrorForEntitieNames(entitiesInfo: [String: NSError]) -> NSError {
        assert(entitiesInfo.count > 0)
        
        let userInfo: [String: AnyObject] = [NSLocalizedDescriptionKey: "Failed to delete objects for at least one entity.", NSLocalizedRecoveryOptionsErrorKey: "Check the \"\(entitiesFialedKey)\" key in the error's userInfo.", entitiesFialedKey: entitiesInfo]
        return NSError(domain: errorDomain, code: DataStoreError.FailedEntityDeletion._code, userInfo: userInfo)
    }
}
