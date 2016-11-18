//
//  MasterViewController.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/13/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class MasterViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {

    fileprivate var stations : [StationInfo]!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        loadStations()
        NSLog ("Loaded stations: \(stations)")
        
        // Do any additional setup after loading the view.
    }

    fileprivate func loadStations() {
        guard let stationListURL = Bundle.main.url(forResource: "station-list", withExtension: "plist"),
        let stationNSArray = NSArray(contentsOf: stationListURL),
        let stationArray = stationNSArray as? [[String : String]] else {
            return
        }
        var stations : [StationInfo] = []
        for stationDict in stationArray {
            if let name = stationDict["name"], let streamURLString = stationDict["streamurl"], let streamURL = URL(string: streamURLString) {
                stations.append(StationInfo(name: name, streamURL: streamURL))
            }
        }
        self.stations = stations
    }
    
    //MARK: - UITableViewDataSource
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return stations.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let station = stations[indexPath.row]
        let cell = tableView.dequeueReusableCell(withIdentifier: "StationCell", for: indexPath) as! StationCellTableViewCell
        cell.nameLabel.text = station.name
        cell.urlLabel.text = station.streamURL.description
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if let splitViewController = splitViewController, splitViewController.viewControllers.count > 1 {
            if let detailVC = splitViewController.viewControllers[1] as? DetailViewController {
            detailVC.station = stations[indexPath.row]
            }
            guard let stationsSplitViewController = splitViewController as? StationsSplitViewController else { return }
            stationsSplitViewController.updateFocusToDetailViewController()
        }
    }
}
