//
//  SettingsViewController.swift
//  Places
//
//  Created by Jad Osseiran on 20/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//

import UIKit

class SettingsViewController : UITableViewController {

    @IBOutlet weak var atomicBatchSwitch: UISwitch!

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
            sharedSettings.atomicBatchSave = atomicBatchSwitch.on
        }
    }

    // MARK: Logic

    private func applySavedSettings() {
        atomicBatchSwitch.on = sharedSettings.atomicBatchSave
    }

    // MARK: Table View

    override func tableView(tableView: UITableView, willDisplayCell cell: UITableViewCell, forRowAtIndexPath indexPath: NSIndexPath) {
        if indexPath == sharedSettings.checkedThreadIndexPath ||
            indexPath == sharedSettings.checkedDelayIndexPath ||
            indexPath == sharedSettings.checkedBatchIndexPath {
                cell.accessoryType = .Checkmark
        }
    }

    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        tableView.deselectRowAtIndexPath(indexPath, animated: true)

        var oldIndexPath: NSIndexPath!
        switch indexPath.section {
        case sharedSettings.threadSection:
            if let thread = Settings.Thread(rawValue: indexPath.row) {
                oldIndexPath = sharedSettings.checkedThreadIndexPath.copy() as! NSIndexPath
                sharedSettings.thread = thread
            }
        case sharedSettings.delaySection:
            if let delayDuration = Settings.DelayDuration(rawValue: indexPath.row) {
                oldIndexPath = sharedSettings.checkedDelayIndexPath.copy() as! NSIndexPath
                sharedSettings.delayDuration = delayDuration
            }
        case sharedSettings.batchSection:
            if let batchSize = Settings.BatchSize(rawValue: indexPath.row) {
                oldIndexPath = sharedSettings.checkedBatchIndexPath.copy() as! NSIndexPath
                sharedSettings.batchSize = batchSize
            }
        default:
            return
        }

        if oldIndexPath != nil {
            let oldCell = tableView.cellForRowAtIndexPath(oldIndexPath)
            oldCell?.accessoryType = .None

            let newCell = tableView.cellForRowAtIndexPath(indexPath)
            newCell?.accessoryType = .Checkmark
        }
    }
}
