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


  // MARK: - Outlets

  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!


  // MARK: - IBActions

  @IBAction func onStyleButtonPressed(_ sender: UIButton) {

  }

  @IBAction func onResetButtonPressed(_ sender: UIButton) {

  }

  @IBAction func onDebugOptionsButtonPressed(_ sender: UIButton) {

  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    initSceneView()
    initScene()
    initARSession()
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
    if let scene = SCNScene(named: "Planets.scnassets/Planets.scn") {
      scene.isPaused = false
      sceneView.scene = scene
    }
  }

  private func initARSession() {
    guard ARWorldTrackingConfiguration.isSupported else {
      print("*** ARConfig: AR World Tracking Not Supported")
      return
    }

    let config = ARWorldTrackingConfiguration()
    config.worldAlignment = .gravity
    config.providesAudioData = false
    sceneView.session.run(config)
  }

  // MARK: Load models

  

  // MARK: - Helper functions



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
