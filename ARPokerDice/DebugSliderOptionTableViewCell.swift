//
//  DebugSliderOptionTableViewCell.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 25.06.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights  reserved.
//

import UIKit

class DebugSliderOptionTableViewCell: UITableViewCell {

  @IBOutlet var descriptionLabel: UILabel!
  @IBOutlet var valueLabel: UILabel!
  @IBOutlet var valueSlider: UISlider!

  var onValueChangeAction: ((_ value: CGFloat) -> ())?

  @IBAction func onSliderValueChanged(_ sender: UISlider) {
    let value = CGFloat(sender.value)
    valueLabel.text = String(format: "%.2f", value)
    onValueChangeAction?(value)
  }

  override func prepareForReuse() {
    super.prepareForReuse()
    descriptionLabel.text = nil
    valueLabel.text = nil
    valueSlider.value = 0
    onValueChangeAction = nil
  }
}
