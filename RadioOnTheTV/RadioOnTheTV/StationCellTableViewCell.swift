//
//  StationCellTableViewCell.swift
//  RadioOnTheTV
//
//  Created by Chris Adamson on 3/13/16.
//  Copyright © 2016 Subsequently & Furthermore, Inc. All rights reserved.
//

import UIKit

class StationCellTableViewCell: UITableViewCell {

    @IBOutlet weak var nameLabel: UILabel!
    @IBOutlet weak var urlLabel: UILabel!
    
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)

        // Configure the view for the selected state
    }

}
