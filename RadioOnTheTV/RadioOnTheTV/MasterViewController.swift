//
//  MasterViewController.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/13/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class MasterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    private var stations : [StationInfo]!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadStations()
        NSLog ("Loaded stations: \(stations)")
        
        // Do any additional setup after loading the view.
    }

    private func loadStations() {
        guard let stationListURL = NSBundle.mainBundle().URLForResource("station-list", withExtension: "plist"),
        stationNSArray = NSArray(contentsOfURL: stationListURL),
        stationArray = stationNSArray as? [[String : String]] else {
            return
        }
        var stations : [StationInfo] = []
        for stationDict in stationArray {
            if let name = stationDict["name"], streamURLString = stationDict["streamurl"], streamURL = NSURL(string: streamURLString) {
                stations.append(StationInfo(name: name, streamURL: streamURL))
            }
        }
        self.stations = stations
    }
    
    //MARK: - UITableViewDataSource
    func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stations.count
    }
    
    func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let station = stations[indexPath.row]
        let cell = tableView.dequeueReusableCellWithIdentifier("StationCell", forIndexPath: indexPath) as! StationCellTableViewCell
        cell.nameLabel.text = station.name
        cell.urlLabel.text = station.streamURL.description
        return cell
    }
    
    func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if let splitViewController = splitViewController
            where splitViewController.viewControllers.count > 1 {
            if let detailVC = splitViewController.viewControllers[1] as? DetailViewController {
            detailVC.station = stations[indexPath.row]
            }
            guard let stationsSplitViewController = splitViewController as? StationsSplitViewController else { return }
            stationsSplitViewController.updateFocusToDetailViewController()
        }
    }
}
