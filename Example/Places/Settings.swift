//
//  Settings.swift
//  Places
//
//  Created by Jad Osseiran on 28/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//

import Foundation

var sharedSettings = Settings()

struct Settings {
    enum Thread: Int {
        case Main = 0, Background, Mixed
    }
    var thread = Thread.Main

    enum DelayDuration: Int {
        case None = 0
        case OneSecond
        case FiveSeconds
        case TenSeconds
        case ThirtySeconds
    }
    var delayDuration = DelayDuration.None

    enum BatchSize: Int {
        case OneItem = 1
        case TwoItems
        case FiveItems
        case TwentyItems
        case FiftyItems
        case HunderdItems
    }
    var batchSize = BatchSize.OneItem
    var atomicBatchSave = false

    // Index Path Helpers

    let threadSection = 0
    var checkedThreadIndexPath: NSIndexPath {
        let row: Int
        switch thread {
        case .Main:
            row = 0
        case .Background:
            row = 1
        case .Mixed:
            row = 2
        }
        return NSIndexPath(forRow: row, inSection: 0)
    }

    let delaySection = 1
    var checkedDelayIndexPath: NSIndexPath {
        let row: Int
        switch delayDuration {
        case .None:
            row = 0
        case .OneSecond:
            row = 1
        case .FiveSeconds:
            row = 2
        case .TenSeconds:
            row = 3
        case .ThirtySeconds:
            row = 4
        }
        return NSIndexPath(forRow: row, inSection: 1)
    }

    let batchSection = 2
    var checkedBatchIndexPath: NSIndexPath {
        let row: Int
        switch batchSize {
        case .OneItem:
            row = 1
        case .TwoItems:
            row = 2
        case .FiveItems:
            row = 3
        case .TwentyItems:
            row = 4
        case .FiftyItems:
            row = 5
        case .HunderdItems:
            row = 6
        }
        return NSIndexPath(forRow: row, inSection: 2)
    }
}
