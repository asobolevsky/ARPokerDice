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

enum SliderDebugOption: Hashable {
  case worldSpeed
}

class DebugOptionsViewController: UIViewController {

  // MARK: - Properties

  private var sectionTitles: [String] = [
    "UI options",
    "Physics"
  ]

  private var switchDebugOptions: [DebugOption] = [
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

  private var sliderDebugOptionTitles: [SliderDebugOption: String] = [
    .worldSpeed: "World Speed"
  ]

  var selectedOptions: SCNDebugOptions = []
  var currentSliderOptionValues: [SliderDebugOption: CGFloat] = [:]
  var sliderOptions: [SliderDebugOption] {
    return Array(currentSliderOptionValues.keys)
  }
  var onDismissBlock: ((SCNDebugOptions, [SliderDebugOption: CGFloat]) -> ())?

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
      onDismissBlock?(selectedOptions, currentSliderOptionValues)
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

    guard let cell = tableView.cellForRow(at: indexPath) as? DebugSwitchOptionTableViewCell else {
      return
    }

    cell.selectedSwitch.isOn = !cell.selectedSwitch.isOn
    let option = switchDebugOptions[indexPath.row]
    toggleDebugOption(option.value)

    let generator = UIImpactFeedbackGenerator(style: .light)
    generator.impactOccurred()
  }

}


// MARK: - UITableViewDataSource

extension DebugOptionsViewController: UITableViewDataSource {

  func numberOfSections(in tableView: UITableView) -> Int {
    return sectionTitles.count
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0: return switchDebugOptions.count
    case 1: return sliderOptions.count

    default: fatalError("Unexpected section \(section)")
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    switch indexPath.section {
    case 0: return configureSwitchOptionCell(in: tableView, for: indexPath)
    case 1: return configureSliderOptionCell(in: tableView, for: indexPath)

    default: fatalError("Unexpected section \(indexPath.section)")
    }
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    return sectionTitles[section]
  }

  private func configureSwitchOptionCell(in tableView: UITableView, for indexPath: IndexPath) -> DebugSwitchOptionTableViewCell {
    print(tableView.dequeueReusableCell(withIdentifier: .debugSwitchOptionCellIdentifier, for: indexPath))
    let cell = tableView.dequeueReusableCell(withIdentifier: .debugSwitchOptionCellIdentifier, for: indexPath) as! DebugSwitchOptionTableViewCell

    let option = switchDebugOptions[indexPath.row]
    cell.descriptionLabel.text = option.description
    cell.selectedSwitch.isOn = selectedOptions.contains(option.value)
    cell.onSelectAction = { [unowned self] _ in
      self.toggleDebugOption(option.value)
    }

    return cell
  }

  private func configureSliderOptionCell(in tableView: UITableView, for indexPath: IndexPath) -> DebugSliderOptionTableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: .debugSliderOptionCellIdentifier, for: indexPath) as! DebugSliderOptionTableViewCell

    let option = sliderOptions[indexPath.row]
    let value: CGFloat = currentSliderOptionValues[option] ?? 0.0
    cell.descriptionLabel.text = sliderDebugOptionTitles[option]
    cell.valueLabel.text = String(format: "%.2f", value)
    cell.valueSlider.value = Float(value)

    cell.onValueChangeAction = { [unowned self] value in
      self.currentSliderOptionValues[option] = value
    }

    return cell
  }

}

private extension String {
  static let debugSwitchOptionCellIdentifier = "debugSwitchOption"
  static let debugSliderOptionCellIdentifier = "debugSliderOption"
}
