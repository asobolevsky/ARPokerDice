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

class ViewController: UIViewController {

  // MARK: - Properties
  var trackingStatus = "" {
    didSet {
      updateStatusLabel()
    }
  }

  let game = Game()
  var diceCount: Int = 5
  var diceStyle: Int = 0
  var diceOffset: [SCNVector3] = [SCNVector3(0.0,0.0,0.0),
                                  SCNVector3(-0.15, 0.00, 0.0),
                                  SCNVector3(0.15, 0.00, 0.0),
                                  SCNVector3(-0.15, 0.15, 0.12),
                                  SCNVector3(0.15, 0.15, 0.12)]
  var focusPoint: CGPoint = .zero

  // MARK: - Outlets

  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!


  // MARK: - IBActions

  @IBAction func onStyleButtonPressed(_ sender: UIButton) {
    game.changeStyle()
  }

  @IBAction func onResetButtonPressed(_ sender: UIButton) {

  }

  @IBAction func onSwipeUp(_ sender: UISwipeGestureRecognizer) {
    guard let frame = sceneView.session.currentFrame else {
      return
    }

    for i in 0..<diceCount {
      throwDice(transform: SCNMatrix4(frame.camera.transform), offset: diceOffset[i])
    }
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
        debugOptionsController.onDismissBlock = { [weak self] debugOptions in
          self?.sceneView.debugOptions = debugOptions
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
    config.planeDetection = [.horizontal]
    sceneView.session.run(config)
  }

  private func initGame() {
    game.loadModels(into: sceneView.scene)
    game.stateUpdateCallback = updateStatusChange
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
  }

  // MARK: - Helper functions

  private func throwDice(transform: SCNMatrix4, offset: SCNVector3) {
    do {
      try game.throwDice(transform: transform, offset: offset) { [unowned self] diceNode in
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
    planeNode.position = SCNVector3(planeAnchor.center.x, 0, planeAnchor.center.z)
    planeNode.transform = SCNMatrix4MakeRotation(-Float.pi / 2, 1, 0, 0)

    return planeNode
  }

  private func updateARPlaneNode(planeNode: SCNNode, planeAnchor: ARPlaneAnchor) {
    if let planeGeometry = planeNode.geometry as? SCNPlane {
      planeGeometry.width = CGFloat(planeAnchor.extent.x)
      planeGeometry.height = CGFloat(planeAnchor.extent.z)
    }

    planeNode.position = SCNVector3Make(planeAnchor.center.x, 0, planeAnchor.center.z)
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


  // MARK: - UI

  private func updateStatusLabel() {
    DispatchQueue.main.async {
      self.statusLabel.text = self.trackingStatus
    }
  }

  private func updateStatusChange(for newState: GameState) {
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

  private func showOverlay() {

  }

  private func hideOverlay() {

  }

}


// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

  func sessionWasInterrupted(_ session: ARSession) {
    trackingStatus = "AR Session Was Interrupted!"
    showOverlay()
  }

  func sessionInterruptionEnded(_ session: ARSession) {
    trackingStatus = "AR Session Interruption Ended"
    hideOverlay()
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
}

// MARK: - ARCoachingOverlayViewDelegate

extension ViewController: ARCoachingOverlayViewDelegate {
  func coachingOverlayViewWillActivate(_ coachingOverlayView: ARCoachingOverlayView) {

  }

  func coachingOverlayViewDidDeactivate(_ coachingOverlayView: ARCoachingOverlayView) {

  }

  func coachingOverlayViewDidRequestSessionReset(_ coachingOverlayView: ARCoachingOverlayView) {

  }
}


private extension String {
  static let debugOptionsSegueIdentifier = "showDebugOptions"
}
