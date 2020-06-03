//
//  Game.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 01.06.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights reserved.
//

import Foundation
import SceneKit

enum GameErrors: Error {
  case maxDiceCountReached
}

enum DiceStyle: Int {
  case cracked
  case metal
  case ivory
  case wood
  case plate
}

enum GameState {
  case detectSurface
  case pointToSurface
  case swipeToPlay
}

class Game {

  private let maxDiceCount = 5
  private var currentDiceCount = 0
  private var diceNodes: [DiceStyle: SCNNode] = [:]
  private var currentStyle: DiceStyle = .cracked
  var focusNode: SCNNode!

  var gameState: GameState = .detectSurface {
    didSet {
      if oldValue != gameState {
        stateUpdateCallback?(gameState)
      }
    }
  }
  var stateUpdateCallback: ((GameState) -> ())?

  func loadModels(into scene: SCNScene) {
    guard let diceScene = SCNScene(named: "PokerDice.scnassets/DiceScene.scn") else {
      print("Could not load dice scene")
      return
    }

    for style in [DiceStyle.cracked, .metal, .ivory, .wood, .plate] {
      let diceNodeName = "dice\(style.rawValue)"
      guard let diceNode = diceScene.rootNode.childNode(withName: diceNodeName, recursively: false) else {
        print("Could not load dice node with name: \(diceNodeName)")
        continue
      }

      diceNodes[style] = diceNode
    }

    guard let focusScene = SCNScene(named: "PokerDice.scnassets/Models/Obelisk.scn"),
      let focusNode = focusScene.rootNode.childNode(withName: "focus", recursively: false) else {
      print("Could not load cursore mode")
      return
    }

    self.focusNode = focusNode
    scene.rootNode.addChildNode(focusNode)
  }

  func throwDice(transform: SCNMatrix4,
                 offset: SCNVector3,
                 completion: (SCNNode) -> ()) throws {
    guard currentDiceCount < maxDiceCount else {
      throw GameErrors.maxDiceCountReached
    }

    let position = SCNVector3(transform.m41 + offset.x,
                              transform.m42 + offset.y,
                              transform.m43 + offset.z)

    guard let diceNode = diceNodes[currentStyle]?.clone() else {
      print("Could not find node with style: \(currentStyle)")
      return
    }

    diceNode.name = "dice"
    diceNode.position = position

    completion(diceNode)
    currentDiceCount += 1
  }

  func changeStyle() {
    // TODO: Now it simply sets the following style. Come up with idea of players.
    if let newStyle = DiceStyle(rawValue: currentStyle.rawValue + 1) {
      currentStyle = newStyle
    } else {
      currentStyle = .cracked
    }
  }

}
