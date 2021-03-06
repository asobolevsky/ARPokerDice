//
//  ViewController.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 26.05.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights reserved.
//

import UIKit
import SceneKit
import ARKit

let kDefaultWorldSpeed: CGFloat = 1
let kDiceCount: Int = 5

class ViewController: UIViewController {
  
  // MARK: - Properties
  var trackingStatus = "" {
    didSet {
      updateStatusLabel()
    }
  }
  
  let game = Game(diceCount: kDiceCount)
  var focusPoint: CGPoint = .zero
  var gameHasStarted = false
  var selectedPlane: SCNNode?
  var coachingOverlay: ARCoachingOverlayView?
  
  
  // MARK: - Outlets
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!
  @IBOutlet var scoreLabel: UILabel!
  @IBOutlet var startButton: UIButton!
  @IBOutlet var hudLabel: UILabel!
  
  
  // MARK: - IBActions
  
  @IBAction func onStyleButtonPressed(_ sender: UIButton) {
    game.changeStyle()
  }
  
  @IBAction func onResetButtonPressed(_ sender: UIButton) {
    resetGame()
  }
  
  @IBAction func onStartButtonPressed(_ sender: UIButton) {
    startGame()
  }
  
  @IBAction func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
    guard game.gameState == .swipeToPlay else {
      return
    }
    
    guard let frame = sceneView.session.currentFrame else {
      return
    }
    
    throwDice(transform: SCNMatrix4(frame.camera.transform))
  }
  
  
  // MARK: - Lifecycle
  
  override func viewDidLoad() {
    super.viewDidLoad()
    
    initSceneView()
    initScene()
    initCoachingOverlayView()
    initGame()
  }
  
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    
    initARSession()
  }
  
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    
    sceneView.session.pause()
  }
  
  override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
    DispatchQueue.main.async {
      guard let touchLocation = touches.first?.location(in: self.sceneView) else {
        return
      }
      
      guard let hit = self.sceneView.hitTest(touchLocation, options: nil).first else {
        return
      }
      
      let hitNode = hit.node
      guard let hitNodeName = hitNode.name?.split(separator: "_").first else {
        return
      }
      
      switch hitNodeName {
      case .diceNodeName:
        self.removeValueFromUserScore(for: hitNode)
        hitNode.removeFromParentNode()
        self.game.currentDiceCount -= 1
        
      case .planeNodeName:
        self.selectedPlane = hitNode
        
      default: print("Tapped unknown node")
      }
    }
  }
  
  override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
    guard let identifier = segue.identifier else {
      return
    }
    
    switch identifier {
    case .debugOptionsSegueIdentifier:
      if let debugOptionsController = segue.destination as? DebugOptionsViewController {
        debugOptionsController.selectedOptions = sceneView.debugOptions
        debugOptionsController.currentSliderOptionValues = [
          .worldSpeed: sceneView.scene.physicsWorld.speed
        ]
        debugOptionsController.onDismissBlock = { [weak self] debugOptions, sliderOptionValues in
          self?.sceneView.debugOptions = debugOptions
          
          for (option, value) in sliderOptionValues {
            switch option {
            case .worldSpeed: self?.sceneView.scene.physicsWorld.speed = value
            }
          }
        }
      }
      
    default: break
    }
  }
  
  deinit {
    NotificationCenter.default.removeObserver(self)
  }
  
  
  // MARK: - Initialization
  
  private func initSceneView() {
    sceneView.delegate = self
    sceneView.showsStatistics = true
    adjustFocusPoint()
    
    NotificationCenter.default.addObserver(self,
                                           selector: #selector(ViewController.orientationChanged),
                                           name: UIDevice.orientationDidChangeNotification,
                                           object: nil)
  }
  
  private func initScene() {
    let scene = SCNScene()
    scene.isPaused = false
    scene.physicsWorld.speed = kDefaultWorldSpeed
    scene.physicsWorld.timeStep = 1.0 / 60.0
    scene.physicsWorld.contactDelegate = self
    sceneView.scene = scene
  }
  
  private func initARSession() {
    guard ARWorldTrackingConfiguration.isSupported else {
      print("*** ARConfig: AR World Tracking Not Supported")
      return
    }
    
    let config = ARWorldTrackingConfiguration()
    config.worldAlignment = .gravity
    config.providesAudioData = false
    config.environmentTexturing = .automatic
    config.isLightEstimationEnabled = true
    config.planeDetection = [.horizontal]
    sceneView.session.run(config)
  }
  
  private func initGame() {
    game.loadModels(into: sceneView.scene)
    game.gameStateDidChange = handleGameStateChange
    game.stateDidChange = updateHUDLabel
    updateHUDLabel()
  }
  
  private func adjustFocusPoint() {
    focusPoint = CGPoint(x: view.center.x, y: view.center.y * 1.25)
  }
  
  @objc func orientationChanged() {
    adjustFocusPoint()
  }
  
  private func initCoachingOverlayView() {
    let coachingOverlay = ARCoachingOverlayView()
    coachingOverlay.session = sceneView.session
    coachingOverlay.activatesAutomatically = true
    coachingOverlay.goal = .horizontalPlane
    coachingOverlay.delegate = self
    sceneView.addSubview(coachingOverlay)
    
    coachingOverlay.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      coachingOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      coachingOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      coachingOverlay.topAnchor.constraint(equalTo: view.topAnchor),
      coachingOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    self.coachingOverlay = coachingOverlay
  }
  
  // MARK: - Helper functions
  
  private func startGame() {
    guard game.gameState == .pointToSurface else {
      return
    }
    
    DispatchQueue.main.async {
      self.gameHasStarted = true
      self.startButton.isHidden = true
      self.suspendARPlaneDetection()
      self.prepareSelectedPlane()
      self.game.start()
    }
  }
  
  private func resetGame() {
    DispatchQueue.main.async {
      self.resetARSession()
      self.game.reset()
    }
  }
  
  private func throwDice(transform: SCNMatrix4) {
    do {
      try game.throwDice(transform: transform) { [unowned self] diceNode in
        self.sceneView.scene.rootNode.addChildNode(diceNode)
      }
    } catch {
      guard let gameError = error as? GameErrors else {
        print("Unknown error: \(error)")
        return
      }
      switch gameError {
      case .maxDiceCountReached:
        print("Max nnumber of dices has been reached")
        
      }
    }
  }
  
  private func createARPlaneNode(planeAnchor: ARPlaneAnchor, color: UIColor) -> SCNNode {
    let planeGeometry = SCNPlane(width: CGFloat(planeAnchor.extent.x),
                                 height: CGFloat(planeAnchor.extent.z))
    
    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = "PokerDice.scnassets/Textures/Surface_DIFFUSE.png"
    planeGeometry.materials = [planeMaterial]
    
    let planeNode = SCNNode(geometry: planeGeometry)
    planeNode.name = .planeNodeName
    planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
    planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)
    planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
    planeNode.categoryBitMask = ModelCategory.plane.rawValue
    
    return planeNode
  }
  
  private func createARPlanePhysics(geometry: SCNGeometry) -> SCNPhysicsBody {
    let physicsShape = SCNPhysicsShape(geometry: geometry, options: nil)
    let physicsBody = SCNPhysicsBody(type: .kinematic, shape: physicsShape)
    physicsBody.restitution = 0.5
    physicsBody.friction = 0.5
    physicsBody.categoryBitMask = ModelCategory.plane.rawValue
    return physicsBody
  }
  
  private func updateARPlaneNode(planeNode: SCNNode, planeAnchor: ARPlaneAnchor) {
    if let planeGeometry = planeNode.geometry as? SCNPlane {
      planeGeometry.width = CGFloat(planeAnchor.extent.x)
      planeGeometry.height = CGFloat(planeAnchor.extent.z)
      planeNode.physicsBody = nil
      planeNode.physicsBody = createARPlanePhysics(geometry: planeGeometry)
    }
    
    planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
  }
  
  private func suspendARPlaneDetection() {
    guard let config = sceneView.session.configuration as? ARWorldTrackingConfiguration else {
      return
    }
    
    config.planeDetection = []
    sceneView.session.run(config)
  }
  
  private func resetARSession() {
    guard let config = sceneView.session.configuration as? ARWorldTrackingConfiguration else {
      return
    }
    
    config.planeDetection = .horizontal
    sceneView.session.run(config, options: [ .resetTracking, .removeExistingAnchors ])
  }
  
  private func updateFocusNode() {
    let hitTestOptions: [SCNHitTestOption: Any] = [
      .categoryBitMask : ModelCategory.plane.rawValue,
      .searchMode: SCNHitTestSearchMode.all.rawValue
    ]
    let result = sceneView.hitTest(focusPoint, options: hitTestOptions)
    if let match = result.first {
      selectedPlane = match.node
      
      game.focusNode.position = match.worldCoordinates
      if gameHasStarted {
        game.gameState = .swipeToPlay
      }
      game.focusNode.isHidden = false
    } else {
      game.gameState = .pointToSurface
      game.focusNode.isHidden = true
    }
  }
  
  private func updateDiceNode() {
    sceneView.scene.rootNode.childNodes { node, _ in node.name?.starts(with: String.diceNodeName) ?? false }
      .filter { $0.presentation.position.y < -2 }
      .forEach { node in
        self.removeValueFromUserScore(for: node)
        node.removeFromParentNode()
        game.currentDiceCount -= 1
      }
  }
  
  
  // MARK: - UI
  
  private func updateStatusLabel() {
    DispatchQueue.main.async {
      self.statusLabel.text = self.trackingStatus
    }
  }
  
  private func updateUserScore() {
    let score = self.game.userScore
    let scoreValues = score.map { self.game.stringForDiceValue($0) }
    DispatchQueue.main.async {
      self.scoreLabel.text = "Score: \(scoreValues)"
    }
  }
  
  private func handleGameStateChange(oldState: GameState, newState: GameState) {
    DispatchQueue.main.async {
      let statusMessage: String
      
      switch newState {
      case .detectSurface:
        statusMessage = "Scan entire table surface..."
      case .pointToSurface:
        statusMessage = "Point at designated surface first!"
      case .swipeToPlay:
        statusMessage = "Swipe UP to throw!\nTap die to collect."
      }
      
      let alert = UIAlertController(title: nil, message: statusMessage , preferredStyle: .actionSheet)
      self.present(alert, animated: true) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
          self.dismiss(animated: true, completion: nil)
        }
      }
    }
  }
  
  private func updateHUDLabel() {
    DispatchQueue.main.async {
      var text = ""
      text += "Dice Count: \(self.game.currentDiceCount)/\(self.game.maxDiceCount)"
      self.hudLabel.text = text
    }
  }
  
  private func updateSceneNodesVisibility(isHidden: Bool) {
    game.focusNode.isHidden = isHidden
    sceneView.scene.rootNode
      .childNodes { node, _ in node.name == .planeNodeName }
      .forEach { $0.isHidden = isHidden }
  }
  
}


// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {
  
  func sessionWasInterrupted(_ session: ARSession) {
    trackingStatus = "AR Session Was Interrupted!"
  }
  
  func sessionInterruptionEnded(_ session: ARSession) {
    trackingStatus = "AR Session Interruption Ended"
    resetGame()
  }
  
  func session(_ session: ARSession, didFailWithError error: Error) {
    trackingStatus = "AR Session Failure: \(error)"
  }
  
  func session(_ session: ARSession, cameraDidChangeTrackingState camera: ARCamera) {
    switch camera.trackingState {
    case .notAvailable:
      trackingStatus = "Tacking: Not available!"
      
    case .normal:
      trackingStatus = ""
      
    case .limited(let reason):
      switch reason {
      case .excessiveMotion:
        trackingStatus = "Tracking: Limited due to excessive motion!"
      case .insufficientFeatures:
        trackingStatus = "Tracking: Limited due to insufficient features!"
      case .initializing:
        trackingStatus = "Tracking: Initializing..."
      case .relocalizing:
        trackingStatus = "Tracking: Relocalizing..."
      @unknown default:
        trackingStatus = "Tracking: Unknown..."
      }
    }
  }
  
  
  // MARK: - Plane management
  
  func renderer(_ renderer: SCNSceneRenderer, updateAtTime time: TimeInterval) {
    updateFocusNode()
    updateDiceNode()
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
    guard let planeAnchor = anchor as? ARPlaneAnchor else {
      return
    }
    
    DispatchQueue.main.async {
      let planeNode = self.createARPlaneNode(planeAnchor: planeAnchor, color: UIColor.yellow.withAlphaComponent(0.5))
      node.addChildNode(planeNode)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let planeNode = node.childNodes.first, let planeAnchor = anchor as? ARPlaneAnchor else {
      return
    }
    
    DispatchQueue.main.async {
      self.updateARPlaneNode(planeNode: planeNode, planeAnchor: planeAnchor)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard let planeNode = node.childNodes.first else {
      return
    }
    
    DispatchQueue.main.async {
      self.removeARPlaneNode(planeNode)
    }
  }
  
  private func prepareSelectedPlane() {
    guard let selectedPlane = selectedPlane else {
      return
    }
    
    removeUnusedARPlaneNodes(ignore: [selectedPlane])
    highlightARPlaneNode(selectedPlane)
  }
  
  private func removeARPlaneNode(_ node: SCNNode) {
    node.removeFromParentNode()
  }
  
  private func highlightARPlaneNode(_ node: SCNNode) {
    let firstMaterial = node.geometry?.firstMaterial
    firstMaterial?.diffuse.contents = UIColor.systemYellow.withAlphaComponent(0.5)
    node.addHightlightBorder()
  }
  
  private func removeUnusedARPlaneNodes(ignore ignoreNodes: [SCNNode] = []) {
    guard let frame = sceneView.session.currentFrame else {
      return
    }
    
    frame.anchors.compactMap { sceneView.node(for: $0) }
      .reduce([SCNNode]()) { (children, node) in
        var children = children
        children.append(contentsOf: node.childNodes)
        return children
      }
      .forEach { plane in
        let shouldDeletePlane = (ignoreNodes.contains(plane) == false)
        if shouldDeletePlane {
          removeARPlaneNode(plane)
        }
      }
  }
  
  private func extractDiceNodeIndex(from node: SCNNode) -> Int? {
    guard
      let diceNodeIndexString = node.name?.split(separator: "_").last,
      let diceNodeIndex = Int(diceNodeIndexString)
    else {
      return nil
    }
    
    return diceNodeIndex
  }
  
  private func addValueToUserScore(for diceFaceNode: SCNNode) {
    guard
      let diceNode = diceFaceNode.parent,
      let diceNodeIndex = extractDiceNodeIndex(from: diceNode),
      let diceValue = game.extractDicePokerValue(from: diceFaceNode)
    else {
      return
    }
    
    game.userScore[diceNodeIndex] = diceValue
    updateUserScore()
  }
  
  private func removeValueFromUserScore(for diceNode: SCNNode) {
    guard let diceNodeIndex = extractDiceNodeIndex(from: diceNode) else {
      return
    }
    
    game.userScore[diceNodeIndex] = .none
    updateUserScore()
  }
}

// TODO: - add invisible spheres to each side of the dice, and track which one contacts with the plane


// MARK: - SCNPhysicsContactDelegate

extension ViewController: SCNPhysicsContactDelegate {
  private func isContact(_ contact: SCNPhysicsContact,
                         between categoryA: ModelCategory,
                         and categoryB: ModelCategory) -> Bool {
    guard
      let physicsBodyA = contact.nodeA.physicsBody,
      let physicsBodyB = contact.nodeB.physicsBody
    else {
      return false
    }
    
    return (physicsBodyA.categoryBitMask | physicsBodyB.categoryBitMask) ==
      (categoryA.rawValue | categoryB.rawValue)
  }
  
  private func node(with category: ModelCategory, in contact: SCNPhysicsContact) -> SCNNode? {
    if contact.nodeA.physicsBody?.categoryBitMask == category.rawValue {
      return contact.nodeA
    }
    
    if contact.nodeB.physicsBody?.categoryBitMask == category.rawValue {
      return contact.nodeB
    }
    
    return nil
  }
  
  func physicsWorld(_ world: SCNPhysicsWorld, didBegin contact: SCNPhysicsContact) {
    if isContact(contact, between: .diceFace, and: .plane) {
      guard let diceFaceNode = node(with: .diceFace, in: contact) else {
        return
      }

      addValueToUserScore(for: diceFaceNode)
    }
  }
}


// MARK: - ARCoachingOverlayViewDelegate

extension ViewController: ARCoachingOverlayViewDelegate {
  func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {
    updateSceneNodesVisibility(isHidden: true)
  }
  
  func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {
    updateSceneNodesVisibility(isHidden: false)
  }
  
  func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {
    resetGame()
  }
}


private extension String {
  static let debugOptionsSegueIdentifier = "showDebugOptions"
}
