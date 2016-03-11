//
//  ViewController.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/6/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

// Armitage's Dimension (AAC): http://armitunes.com:8010/

// Extreme Anime Radio (MP3): http://69.4.225.75:8100/ -- doesn't work
// Extreme Anime Radio (AAC): http://174.123.20.140:8010/

// CBC Radio 3 (MP3): http://8673.live.streamtheworld.com:443/CBC_R3_WEB_SC  // 403's a lot 😟
// (CBCR3 moves around a lot - curl the latest playlist at
// http://playerservices.streamtheworld.com/pls/CBC_R3_WEB.pls
// and grab a URL from in there)

// KZSU-1 Stanford, 128Kbps (MP3): http://171.66.118.51:80/kzsu-1-128.mp3
// KZSU-1 Stanford, 192Kbps (AAC): http://171.66.118.51:80/kzsu-1-192.aac

class ViewController: UIViewController {

    var webRadioPlayer : WebRadioPlayer?
    @IBOutlet weak var addressLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
        
        if let url = NSURL (string: "http://armitunes.com:8010/") {
            addressLabel.text = url.description
            webRadioPlayer = WebRadioPlayer(stationURL: url)
            webRadioPlayer?.start()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }


}

