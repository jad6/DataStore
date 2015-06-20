//
//  DataStoreOperations.swift
//  DataStore
//
//  Created by Jad Osseiran on 12/11/2014.
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

import CoreData

public extension DataStore {
    
    // MARK: - Class Methods
    
    /**
     * Helper method to create an object model from a resource.
     *
     * - parameter resource: The name of the managed object model file.
     * - parameter bundle: The bundle in which to look for.
     *
     * - returns: The initialised object model if found.
     */
    public class func modelForResource(resource: String, bundle: NSBundle) -> NSManagedObjectModel? {
        // Try finding the model with both known model file extensions.
        var modelURL = bundle.URLForResource(resource, withExtension: "momd")
        if modelURL == nil {
            modelURL = bundle.URLForResource(resource, withExtension: "mom")
        }
        // Return nil upon failure.
        if modelURL == nil {
            return nil
        }
        
        return NSManagedObjectModel(contentsOfURL: modelURL!)
    }
    
    // MARK: - Main Queue
    
    /**
     * Method which performs operations asynchronously on the main queue.
     *
     * - parameter closure: The closure to perform on the main queue.
     */
    public func performClosure(closure: ContextClosure) {
        mainManagedObjectContext.performBlock() {
            closure(context: self.mainManagedObjectContext)
        }
    }
    
    /**
     * Method which performs operations and saves asynchronously on the main queue.
     *
     * - parameter closure: The closure to perform on the main queue.
     * - parameter completion: Closure containing an error pointer which is called when the operations and save are completed.
     */
    public func performClosureAndSave(closure: ContextClosure, completion: ContextSaveClosure?) {
        performClosure() { context in
            closure(context: context)
            self.save() { error in
                if completion != nil {
                    completion!(context: context, error: error)
                }
            }
        }
    }
    
    /**
     * Method which performs operations synchronously on the main queue.
     *
     * - parameter closure: The closure to perform on the main queue.
     */
    public func performClosureAndWait(closure: ContextClosure) {
        mainManagedObjectContext.performBlockAndWait() {
            closure(context: self.mainManagedObjectContext)
        }
    }
    
    /**
     * Method which performs operations and saves synchronously on the main queue.
     *
     * - parameter closure: The closure to perform on the main queue.
     * - parameter error: An error pointer which is populated when an error is encountered at save time.
     *
     * - returns: true if the saving operation was a success.
     */
    public func performClosureWaitAndSave(closure: ContextClosure) throws {
        performClosureAndWait() { context in
            closure(context: context)
        }
        do {
            try self.saveAndWait()
        } catch let error {
            throw error
        }
    }
    
    // MARK: - Background Queue

    /**
     * Method which performs operations asynchronously on the background queue.
     *
     * - parameter closure: The closure to perform on the background queue.
     */
    public func performBackgroundClosure(closure: ContextClosure) {
        backgroundManagedObjectContext.performBlock() {
            closure(context: self.backgroundManagedObjectContext)
        }
    }
    
    /**
     * Method which performs operations and saves asynchronously on the background queue.
     *
     * - parameter closure: The closure to perform on the background queue.
     * - parameter completion: Closure containing an error pointer which is called when the operations and save are completed.
     */
    public func performBackgroundClosureAndSave(closure: ContextClosure, completion: ContextSaveClosure?) {
        performBackgroundClosure() { context in
            closure(context: context)
            self.save() { error in
                if completion != nil {
                    completion!(context: context, error: error)
                }
            }
        }
    }
    
    /**
     * Method which performs operations synchronously on the background queue.
     *
     * - parameter closure: The closure to perform on the background queue.
     */
    public func performBackgroundClosureAndWait(closure: ContextClosure) {
        backgroundManagedObjectContext.performBlockAndWait() {
            closure(context: self.backgroundManagedObjectContext)
        }
    }

    /**
     * Method which performs operations and saves synchronously on the background queue.
     *
     * - parameter closure: The closure to perform on the background queue.
     * - parameter error: An error pointer which is populated when an error is encountered at save time.
     *
     * - returns: true if the saving operation was a success.
     */
    public func performBackgroundClosureWaitAndSave(closure: ContextClosure) throws {
        performBackgroundClosureAndWait() { context in
            closure(context: context)
        }

        do {
            try saveAndWait()
        } catch let error {
            throw error
        }
    }
}