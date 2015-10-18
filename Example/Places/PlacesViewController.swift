//
//  PlacesViewController.swift
//  Places
//
//  Created by Jad Osseiran on 20/06/2015.
//  Copyright © 2015 Jad Osseiran. All rights reserved.
//

import UIKit

class PlacesViewController: UITableViewController {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: Actions

    @IBAction func addPlaceOption(sender: AnyObject) {
        let alertController = UIAlertController(title: "Add Place", message: "Add a place into Core Data. The number of places that will be added can be set in the \"Batches\" setting.", preferredStyle: .Alert)
        alertController.addTextFieldWithConfigurationHandler { textField in
            textField.placeholder = "Coral Bay"
            textField.autocapitalizationType = .Words
        }

        let cancelAction = UIAlertAction(title: "Cancel", style: .Cancel, handler: nil)
        alertController.addAction(cancelAction)

        let saveAction = UIAlertAction(title: "Save", style: .Default) { action in
            // Do the actual saving here.
        }
        alertController.addAction(saveAction)

        presentViewController(alertController, animated: true, completion: nil)
    }
}

