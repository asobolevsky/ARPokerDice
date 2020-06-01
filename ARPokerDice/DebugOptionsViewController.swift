//
//  DebugOptionsViewController.swift
//  ARPokerDice
//
//  Created by Alexey Sobolevsky on 27.05.2020.
//  Copyright © 2020 Alexey Sobolevsky. All rights reserved.
//

import UIKit
import SceneKit

typealias DebugOption = (description: String, value: SCNDebugOptions)

class DebugOptionsViewController: UIViewController {

  // MARK: - Properties

  private var debugOptions: [DebugOption] = {
    return [
      ("Show the world origin in the scene", .showWorldOrigin),
      ("Show detected 3D feature points in the world", .showFeaturePoints),
      ("Show physics shape", .showPhysicsShapes),
      ("Show object bounding boxes", .showBoundingBoxes),
      ("Show objects's light influences", .showLightInfluences),
      ("Show light extents", .showLightExtents),
      ("Show SCNPhysicsFields forces and extents", .showPhysicsFields),
      ("Show wireframe on top of objects", .showWireframe),
      ("Render objects as wireframe", .renderAsWireframe),
      ("Show skinning bones", .showSkeletons),
      ("Show subdivision creases", .showCreases),
      ("Show slider constraint", .showConstraints),
      ("Show cameras", .showCameras),
    ]
  }()

  var selectedOptions: SCNDebugOptions = []
  var onDismissBlock: ((SCNDebugOptions) -> ())?

  @IBOutlet var optionsTableView: UITableView!

  // MARK: - Lifecycle

  override func viewDidLoad() {
    super.viewDidLoad()
    optionsTableView.delegate = self
    optionsTableView.dataSource = self
    optionsTableView.rowHeight = UITableView.automaticDimension
    optionsTableView.estimatedRowHeight = 44
  }

  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)

    if isBeingDismissed {
      onDismissBlock?(selectedOptions)
    }
  }

  // MARK: - Private

  private func toggleDebugOption(_ option: SCNDebugOptions) {
    if selectedOptions.contains(option) {
      selectedOptions.remove(option)
    } else {
      selectedOptions.insert(option)
    }
  }

}


// MARK: - UITableViewDelegate

extension DebugOptionsViewController: UITableViewDelegate {

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    tableView.deselectRow(at: indexPath, animated: true)

    guard let cell = tableView.cellForRow(at: indexPath) as? DebugOptionTableViewCell else {
      return
    }

    cell.selectedSwitch.isOn = !cell.selectedSwitch.isOn
    let option = debugOptions[indexPath.row]
    toggleDebugOption(option.value)

    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

}


// MARK: - UITableViewDataSource

extension DebugOptionsViewController: UITableViewDataSource {

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    return debugOptions.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "debugOption", for: indexPath) as! DebugOptionTableViewCell

    let option = debugOptions[indexPath.row]
    cell.descriptionLabel.text = option.description
    cell.selectedSwitch.isOn = selectedOptions.contains(option.value)
    cell.onSelectAction = { [unowned self] _ in
      self.toggleDebugOption(option.value)
    }

    return cell
  }

}
