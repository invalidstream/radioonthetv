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

    fileprivate var player : WebRadioPlayer?

    var station : StationInfo? {
        didSet {
            if let station = station {
                // start playing this station
                player?.pause()
                player = WebRadioPlayer(stationURL: station.streamURL)
                player?.delegate = self
                stationNameLabel.text = station.name
                addressLabel.text = station.streamURL.description
                playPauseButton.isEnabled = true
            } else {
                playPauseButton.isEnabled = false
            }
        }
    }

    override weak var preferredFocusedView: UIView? {
        return playPauseButton.isEnabled ? playPauseButton : nil
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        playPauseButton.isEnabled = false
        // Do any additional setup after loading the view.
    }

    func webRadioPlayerStateChanged(_ player: WebRadioPlayer) {
        NSLog ("state change: \(player.playerInfo.state)")
        updateButton()
    }
    
    fileprivate func updateButton() {
        let controlStates : [UIControlState] = [.selected, .focused, .highlighted, .disabled]
        switch player?.playerInfo.state {
        case .none:
            playPauseButton.isEnabled = false
        case .some(.initialized), .some(.paused):
            playPauseButton.isEnabled = true
            setTitleForButton(playPauseButton, text: "Play", forControlStates: controlStates)
        case .some(.starting):
            playPauseButton.isEnabled = false
            setTitleForButton(playPauseButton, text: "Starting", forControlStates: controlStates)
        case .some(.playing):
            playPauseButton.isEnabled = true
            setTitleForButton(playPauseButton, text: "Pause", forControlStates: controlStates)
        case .some(.error):
            playPauseButton.isEnabled = false
            setTitleForButton(playPauseButton, text: "Error", forControlStates: controlStates)
        }
        updateFocusIfNeeded()
    }
    
    fileprivate func setTitleForButton(_ button: UIButton, text: String, forControlStates controlStates: [UIControlState]) {
        for controlState in controlStates {
            button.setTitle(text, for: controlState)
        }
    }
    
    @IBAction func playPauseTriggered(_ sender: AnyObject) {
        switch player?.playerInfo.state {
        case .some(.initialized):
            player?.start()
        case .some(.paused):
            player?.resume()
        case .some(.playing):
            player?.pause()
        default:
            break
        }
    }
}
