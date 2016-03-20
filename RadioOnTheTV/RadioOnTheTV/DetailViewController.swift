//
//  DetailViewController.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/13/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class DetailViewController: UIViewController, WebRadioPlayerDelegate {

    @IBOutlet weak var stationNameLabel: UILabel!
    @IBOutlet weak var addressLabel: UILabel!
    @IBOutlet weak var playPauseButton: UIButton!

    private var player : WebRadioPlayer?

    var station : StationInfo? {
        didSet {
            if let station = station {
                // start playing this station
                player?.pause()
                player = WebRadioPlayer(stationURL: station.streamURL)
                player?.delegate = self
                stationNameLabel.text = station.name
                addressLabel.text = station.streamURL.description
                playPauseButton.becomeFirstResponder()
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    func webRadioPlayerStateChanged(player: WebRadioPlayer) {
        NSLog ("state change: \(player.playerInfo.state)")
    }
    
    @IBAction func playPauseTriggered(sender: AnyObject) {
        if player?.playerInfo.state == .Some(.Initialized) {
            player?.start()
        }
        else if player?.playerInfo.state == .Some(.Paused) {
            player?.resume()
        }
    }
}
