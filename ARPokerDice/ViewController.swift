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
  var diceOffset: [SCNVector3] = [SCNVector3(0.0,0.0,0.0),
                                  SCNVector3(-0.15, 0.00, 0.0),
                                  SCNVector3(0.15, 0.00, 0.0),
                                  SCNVector3(-0.15, 0.15, 0.12),
                                  SCNVector3(0.15, 0.15, 0.12)]
  var focusPoint: CGPoint = .zero
  var coachingOverlay: ARCoachingOverlayView!
  
  // MARK: - Outlets
  
  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!
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
  p. 138
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
    coachingOverlay = ARCoachingOverlayView()
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
  }
  
  // MARK: - Helper functions
  
  private func startGame() {
    guard game.gameState == .detectSurface else {
      return
    }
    
    DispatchQueue.main.async {
      self.suspendARPlaneDetection()
      self.hideARPlaneNode()
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
    
    return planeNode
  }
  
  private func createARPlanePhysics(geometry: SCNGeometry) -> SCNPhysicsBody {
    let physicsBody = SCNPhysicsBody(type: .kinematic,
                                     shape: SCNPhysicsShape(geometry: geometry, options: nil))
    physicsBody.restitution = 0.5
    physicsBody.friction = 0.5
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
  
  private func removeARPlaneNode(node: SCNNode) {
    node.removeFromParentNode()
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
  
  private func hideARPlaneNode() {
    guard let frame = sceneView.session.currentFrame else {
      return
    }
    
    frame.anchors.compactMap { sceneView.node(for: $0) }
      .reduce([SCNNode]()) { (children, node) in
        var children = children
        children.append(contentsOf: node.childNodes)
        return children
    }.compactMap { $0.geometry?.materials.first }
      .forEach { $0.colorBufferWriteMask = .init(rawValue: 0) }
  }
  
  private func updateFocusNode() {
    let result = sceneView.hitTest(focusPoint, types: [.existingPlaneUsingExtent])
    
    if result.count == 1, let match = result.first {
      let t = match.worldTransform
      game.focusNode.position = SCNVector3(x: t.columns.3.x,
                                           y: t.columns.3.y,
                                           z: t.columns.3.z)
      game.gameState = .swipeToPlay
      game.focusNode.isHidden = false
    } else {
      game.gameState = .pointToSurface
      game.focusNode.isHidden = true
    }
  }
  
  private func updateDiceNode() {
    sceneView.scene.rootNode.childNodes { node, _ in node.name == .diceNodeName }
      .filter { $0.presentation.position.y < -2 }
      .forEach { node in
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
    print("Did add plane")
    DispatchQueue.main.async {
      let planeNode = self.createARPlaneNode(planeAnchor: planeAnchor, color: UIColor.yellow.withAlphaComponent(0.5))
      node.addChildNode(planeNode)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
    guard let planeNode = node.childNodes.first, let planeAnchor = anchor as? ARPlaneAnchor else {
      return
    }
    print("Did update plane")
    DispatchQueue.main.async {
      self.updateARPlaneNode(planeNode: planeNode, planeAnchor: planeAnchor)
    }
  }
  
  func renderer(_ renderer: SCNSceneRenderer, didRemove node: SCNNode, for anchor: ARAnchor) {
    guard let planeNode = node.childNodes.first else {
      return
    }
    print("Did remove plane")
    DispatchQueue.main.async {
      self.removeARPlaneNode(node: planeNode)
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
