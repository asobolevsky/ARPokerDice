//
//  DebugOptionTableViewCell.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 27.05.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights  reserved.
//

import UIKit

class DebugOptionTableViewCell: UITableViewCell {

  @IBOutlet var descriptionLabel: UILabel!
  @IBOutlet var selectedSwitch: UISwitch!

  var onSelectAction: ((_ isSelected: Bool) -> ())?

  @IBAction func onSwitchValueChanged(_ sender: UISwitch) {
    onSelectAction?(sender.isOn)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    descriptionLabel.text = nil
    selectedSwitch.isOn = false
    onSelectAction = nil
  }

}
