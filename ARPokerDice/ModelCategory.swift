//
//  ModelCategory.swift
//  ARPokerDice
//
//  Created by Aleksei Sobolevskii on 2021-01-13.
//  Copyright © 2021 Alexey Sobolevsky. All rights reserved.
//

import Foundation

struct ModelCategory: OptionSet {
  let rawValue: Int

  // default categoryBitMask is 1
  static let plane = ModelCategory(rawValue: 1 << 1)

  static let models: ModelCategory = [ .plane ]
}
