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

  let maxDiceCount: Int
  var currentDiceCount = 0 {
    didSet {
      stateDidChange?()
    }
  }
  var currentDiceStyle: DiceStyle = .cracked {
     didSet {
       stateDidChange?()
     }
   }

  private var diceNodes: [DiceStyle: SCNNode] = [:]
  private var currentStyle: DiceStyle = .cracked
  var focusNode: SCNNode!

  var gameState: GameState = .detectSurface {
    didSet {
      if oldValue != gameState {
        gameStateDidChange?(oldValue, gameState)
      }
    }
  }
  var stateDidChange: (() -> ())?
  var gameStateDidChange: ((GameState, GameState) -> ())?

  init(diceCount: Int) {
    maxDiceCount = diceCount
  }

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

    guard let diceNode = diceNodes[currentStyle]?.clone() else {
      print("Could not find node with style: \(currentStyle)")
      return
    }

    let position = SCNVector3(transform.m41 + offset.x,
                              transform.m42 + offset.y,
                              transform.m43 + offset.z)

    let rotation = SCNVector3(Double.random(min: 0, max: Double.pi),
                              Double.random(min: 0, max: Double.pi),
                              Double.random(min: 0, max: Double.pi))

    let distance = simd_distance(focusNode.simdPosition,
                                 simd_make_float3(transform.m41, transform.m42, transform.m43))
    let direction = SCNVector3(-(distance * 2.5) * transform.m31,
                               -(distance * 2.5) * (transform.m32 - Float.pi / 4),
                               -(distance * 2.5) * transform.m33)

    diceNode.name = .diceNodeName
    diceNode.position = position
    diceNode.eulerAngles = rotation
    diceNode.physicsBody?.resetTransform()
    diceNode.physicsBody?.applyForce(direction, asImpulse: true)
    p. 131
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
