//
//  SettingsViewController.swift
//  Places
//
//  Created by Jad Osseiran on 20/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//

import UIKit

private enum SaveKey: String {
    case Invalid = "InvalidKey"
    case Thread = "SelectedThreadIndexPathKey"
    case Delay = "SelectedDelayIndexPathKey"
    case Batch = "SelectedBatchIndexPathKey"
    case AtomicBatch = "AtomicBatchIndexPathKey"

    static var defaults: NSUserDefaults {
        return NSUserDefaults.standardUserDefaults()
    }

    static func keyForSection(section: Int) -> SaveKey {
        guard section >= 0 && section < 3 else {
            assertionFailure("Invalid section to grab SaveKey")
            return Invalid
        }

        if section == 0 {
            return Thread
        } else if section == 1 {
            return Delay
        } else if section == 2 {
            return Batch
        }

        return Invalid;
    }

    static func sectionForKey(key: SaveKey) -> Int {
        switch key {
        case .Thread:
            return 0
        case .Delay:
            return 1
        case .Batch:
            return 2
        default:
            assertionFailure("The \"AtomicBatch\" key does not store an indexPath")
        }

        return -1
    }

    static func savedIndexPathForKey(key: SaveKey) -> NSIndexPath {
        if key == AtomicBatch || key == Invalid {
            assertionFailure("The \"AtomicBatch\" key does not store an indexPath")
        }

        if let encoded = defaults.objectForKey(key.rawValue) as? NSData {
            if let indexPath = NSKeyedUnarchiver.unarchiveObjectWithData(encoded) as? NSIndexPath {
                return indexPath
            }
        }

        let section = sectionForKey(key)
        return NSIndexPath(forRow: key == Batch ? 1 : 0, inSection: section)
    }

    static func saveIndexPath(indexPath: NSIndexPath, withKey key: SaveKey) {
        let encoded = NSKeyedArchiver.archivedDataWithRootObject(indexPath)
        defaults.setValue(encoded, forKey: key.rawValue)
        defaults.synchronize()
    }

    static func savedAtomicBatchForKey(key: SaveKey) -> Bool {
        return defaults.boolForKey(AtomicBatch.rawValue)
    }

    static func saveAtomicBatch(isAtomicBatch: Bool) {
        defaults.setBool(isAtomicBatch, forKey: AtomicBatch.rawValue)
        defaults.synchronize()
    }
}

class SettingsViewController : UITableViewController {

    @IBOutlet weak var atomicBatchSwitch: UISwitch!

    private var threadIndexPath = NSIndexPath(forRow: 0, inSection: 0)
    private var delayIndexPath = NSIndexPath(forRow: 0, inSection: 1)
    private var batchIndexPath = NSIndexPath(forRow: 1, inSection: 2)

    override func viewDidLoad() {
        super.viewDidLoad()

        applySavedSettings()
    }

    // MARK: Actions

    @IBAction func doneAction(sender: AnyObject?) {
        dismissViewControllerAnimated(true, completion: nil)
    }

    @IBAction func atomicBatchSwitchAction(sender: UISwitch?) {
        if let atomicBatchSwitch = sender {
            SaveKey.saveAtomicBatch(atomicBatchSwitch.on)
        }
    }

    // MARK: Logic

    private func applySavedSettings() {
        atomicBatchSwitch.on = SaveKey.savedAtomicBatchForKey(.AtomicBatch)

        threadIndexPath = SaveKey.savedIndexPathForKey(.Thread)
        delayIndexPath = SaveKey.savedIndexPathForKey(.Delay)
        batchIndexPath = SaveKey.savedIndexPathForKey(.Batch)
    }

    // MARK: Table View

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath == threadIndexPath ||
            indexPath == delayIndexPath ||
            indexPath == batchIndexPath {
                cell.accessoryType = .Checkmark
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        let savedKey = SaveKey.keyForSection(indexPath.section)
        let oldIndexPath = SaveKey.savedIndexPathForKey(savedKey)

        let oldCell = tableView.cellForRowAtIndexPath(oldIndexPath)
        oldCell?.accessoryType = .None

        let newCell = tableView.cellForRowAtIndexPath(indexPath)
        newCell?.accessoryType = .Checkmark

        SaveKey.saveIndexPath(indexPath, withKey: savedKey)
    }
}
