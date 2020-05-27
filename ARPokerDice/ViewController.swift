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



  // MARK: - Outlets

  @IBOutlet var sceneView: ARSCNView!
  @IBOutlet var statusLabel: UILabel!


  // MARK: - IBActions

  @IBAction func onStyleButtonPressed(_ sender: UIButton) {

  }

  @IBAction func onResetButtonPressed(_ sender: UIButton) {

  }

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()

    sceneView.delegate = self
    sceneView.showsStatistics = true
    let scene = SCNScene(named: "PokerDice.scnassets/SimpleScene.scn")!
    sceneView.scene = scene
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

  // MARK: - Initialization

  
}


// MARK: - ARSCNViewDelegate

extension ViewController: ARSCNViewDelegate {

}
