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
                playPauseButton.enabled = true
            } else {
                playPauseButton.enabled = false
            }
        }
    }

    override weak var preferredFocusedView: UIView? {
        return playPauseButton.enabled ? playPauseButton : nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        playPauseButton.enabled = false
        // Do any additional setup after loading the view.
    }

    func webRadioPlayerStateChanged(player: WebRadioPlayer) {
        NSLog ("state change: \(player.playerInfo.state)")
        updateButton()
    }
    
    private func updateButton() {
        let controlStates : [UIControlState] = [.Normal, .Selected, .Focused, .Highlighted, .Disabled]
        switch player?.playerInfo.state {
        case .None:
            playPauseButton.enabled = false
        case .Some(.Initialized), .Some(.Paused):
            playPauseButton.enabled = true
            setTitleForButton(playPauseButton, text: "Play", forControlStates: controlStates)
        case .Some(.Starting):
            playPauseButton.enabled = false
            setTitleForButton(playPauseButton, text: "Starting", forControlStates: controlStates)
        case .Some(.Playing):
            playPauseButton.enabled = true
            setTitleForButton(playPauseButton, text: "Pause", forControlStates: controlStates)
        case .Some(.Error):
            playPauseButton.enabled = false
            setTitleForButton(playPauseButton, text: "Error", forControlStates: controlStates)
        }
        updateFocusIfNeeded()
    }
    
    private func setTitleForButton(button: UIButton, text: String, forControlStates controlStates: [UIControlState]) {
        for controlState in controlStates {
            button.setTitle(text, forState: controlState)
        }
    }
    
    @IBAction func playPauseTriggered(sender: AnyObject) {
        switch player?.playerInfo.state {
        case .Some(.Initialized):
            player?.start()
        case .Some(.Paused):
            player?.resume()
        case .Some(.Playing):
            player?.pause()
        default:
            break
        }
    }
}
