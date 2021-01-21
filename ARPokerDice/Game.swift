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

enum BoxFace: Int {
  case right, left, top, bottom, front, back
}

enum PokerDiceValue: Int {
  case none, nine, ten, jack, queen, king, ace
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
  
  lazy var userScore: [PokerDiceValue] = {
    return [PokerDiceValue](repeating: .none, count: self.maxDiceCount)
  }()
  
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
  
  
  // MARK: - Public
  
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
  
  func throwDice(transform: SCNMatrix4, completion: (SCNNode) -> ()) throws {
    guard currentDiceCount < maxDiceCount else {
      throw GameErrors.maxDiceCountReached
    }
    
    guard let diceNode = diceNodes[currentStyle]?.clone() else {
      print("Could not find node with style: \(currentStyle)")
      return
    }
    
    let position = SCNVector3(transform.m41,
                              transform.m42,
                              transform.m43)
    
    let rotation = SCNVector3(Double.random(min: 0, max: Double.pi),
                              Double.random(min: 0, max: Double.pi),
                              Double.random(min: 0, max: Double.pi))
    
    let distance = simd_distance(focusNode.simdPosition,
                                 simd_make_float3(transform.m41, transform.m42, transform.m43))
    let direction = SCNVector3(-(distance * 2.5) * transform.m31,
                               -(distance * 2.5) * (transform.m32 - Float.pi / 4),
                               -(distance * 2.5) * transform.m33)
    
    diceNode.name = "\(String.diceNodeName)_\(currentDiceCount)"
    diceNode.position = position
    diceNode.eulerAngles = rotation
    let physicsBody = diceNode.physicsBody
    physicsBody?.categoryBitMask = ModelCategory.dice.rawValue
    physicsBody?.collisionBitMask = ModelCategory.plane.rawValue | ModelCategory.dice.rawValue
    physicsBody?.resetTransform()
    physicsBody?.applyForce(direction, asImpulse: true)
    
    setupDiceFaceIndicators(for: diceNode)
    
    completion(diceNode)
    currentDiceCount += 1
  }
  
  func changeStyle() {
    // TODO: - Now it simply sets the following style. Come up with idea of players.
    if let newStyle = DiceStyle(rawValue: currentStyle.rawValue + 1) {
      currentStyle = newStyle
    } else {
      currentStyle = .cracked
    }
  }
  
  func start() {
    gameState = .swipeToPlay
  }
  
  func reset() {
    currentDiceCount = 0
    currentStyle = .cracked
    gameState = .detectSurface
  }
  
  func extractDicePokerValue(from node: SCNNode) -> PokerDiceValue? {
    guard let diceFaceNodeName = node.name,
      let diceFaceRawValueString = diceFaceNodeName.split(separator: "_").last,
      let diceFaceRawValue = Int(diceFaceRawValueString),
      let contactedDiceFace = BoxFace(rawValue: diceFaceRawValue)
    else {
      return nil
    }
    
    return pokerDiceValue(forContactedFace: contactedDiceFace)
  }
  
  func stringForDiceValue(_ value: PokerDiceValue) -> String {
    switch value {
    case .none:   return "-"
    case .nine:   return "9"
    case .ten:    return "10"
    case .jack:   return "J"
    case .queen:  return "Q"
    case .king:   return "K"
    case .ace:    return "A"
    }
  }
  
  
  // MARK: - Private
  
  private func setupDiceFaceIndicators(for dice: SCNNode) {
    guard let (min, max) = dice.geometry?.boundingBox else {
      return
    }
    
    let offsetFromCenter = CGFloat((max.x - min.x) / 2)
    
    // TODO: - Create a container node for the dice and indicators, so that the physical box of the dice remained the same
    var currentFace = BoxFace(rawValue: 0)
    while let face = currentFace {
      let material = SCNMaterial()
      material.diffuse.contents = UIColor.clear
      
      let geometry = SCNSphere(radius: offsetFromCenter / 4)
      geometry.firstMaterial = material
      let physicsShape = SCNPhysicsShape(geometry: geometry, options: nil)
      let physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
      physicsBody.categoryBitMask = ModelCategory.diceFace.rawValue
      physicsBody.contactTestBitMask = ModelCategory.plane.rawValue
      physicsBody.collisionBitMask = ModelCategory.plane.rawValue
      
      let indicatorNode = SCNNode(geometry: geometry)
      indicatorNode.name = "\(String.diceFaceIndicatorNodeName)_\(face.rawValue)"
      indicatorNode.physicsBody = physicsBody
      indicatorNode.position = diceFaceIndicatorPosition(for: face, offset: offsetFromCenter)
      dice.addChildNode(indicatorNode)
      
      currentFace = BoxFace(rawValue: face.rawValue + 1)
    }
  }
  
  private func diceFaceIndicatorPosition(for face: BoxFace, offset: CGFloat) -> SCNVector3 {
    // right, left, top, bottom, front, back
    // z axis
    let axisValue = ((face.rawValue % 2 == 0) ? 1 : -1) * offset
    if face.rawValue >= 4 {
      return SCNVector3(0, 0, axisValue)
    } else if face.rawValue >= 2 {
      return SCNVector3(0, axisValue, 0)
    } else {
      return SCNVector3(axisValue, 0, 0)
    }
  }
  
  private func pokerDiceValue(forContactedFace contactedFace: BoxFace) -> PokerDiceValue {
    switch contactedFace {
    case .right:  return .queen
    case .left:   return .jack
    case .top:    return .nine
    case .bottom: return .ace
    case .front:  return .ten
    case .back:   return .king
    }
  }
  
  private func boxHitFace(from normal: SCNVector3) -> BoxFace? {
    if round(normal.x) == -1 {
        return .left
    } else if round(normal.x) == 1 {
        return .right
    } else if round(normal.y) == -1 {
        return .bottom
    } else if round(normal.y) == 1 {
        return .top
    } else if round(normal.z) == -1 {
        return .back
    } else if round(normal.z) == 1 {
        return .front
    }
    
    return nil
  }
}
