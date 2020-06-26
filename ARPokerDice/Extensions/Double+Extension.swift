//
//  Double+Extension.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 26.06.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights reserved.
//

import Foundation

public extension Double {
  static func random(min: Double, max: Double) -> Double {
    let r64 = Double(arc4random()) / Double(UInt64.max)
    return (r64 * (max - min)) + min
  }
}
