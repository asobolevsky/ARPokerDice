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
    initARSession()

    game.loadModels()
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    let configuration = ARWorldTrackingConfiguration()
    sceneView.session.run(configuration)
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

  // MARK: - Initialization

  private func initSceneView() {
    sceneView.delegate = self
    sceneView.showsStatistics = true
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
    sceneView.session.run(config)
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


  // MARK: - UI

  private func updateStatusLabel() {
    DispatchQueue.main.async {
      self.statusLabel.text = self.trackingStatus
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
}


private extension String {
  static let debugOptionsSegueIdentifier = "showDebugOptions"
}
