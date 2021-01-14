//
//  SCNNode+Extension.swift
//  ARPokerDice
//
//  Created by Aleksei Sobolevskii on 2021-01-13.
//  Copyright © 2021 Alexey Sobolevsky. All rights reserved.
//

import SceneKit

private let kHighlightingNode = "NodeHightlightBorder"

extension SCNNode {
  func addHightlightBorder(color: UIColor = UIColor.white) {
    let (min, max) = boundingBox
    let zCoord = position.z
    let topLeft = SCNVector3Make(min.x, max.y, zCoord)
    let bottomLeft = SCNVector3Make(min.x, min.y, zCoord)
    let topRight = SCNVector3Make(max.x, max.y, zCoord)
    let bottomRight = SCNVector3Make(max.x, min.y, zCoord)
    
    let bottomSide = createLineNode(fromPos: bottomLeft, toPos: bottomRight, color: color)
    let leftSide = createLineNode(fromPos: bottomLeft, toPos: topLeft, color: color)
    let rightSide = createLineNode(fromPos: bottomRight, toPos: topRight, color: color)
    let topSide = createLineNode(fromPos: topLeft, toPos: topRight, color: color)
    
    [bottomSide, leftSide, rightSide, topSide].forEach {
      $0.name = kHighlightingNode // Whatever name you want so you can unhighlight later if needed
      addChildNode($0)
    }
  }
  
  private func createLineNode(fromPos origin: SCNVector3, toPos destination: SCNVector3, color: UIColor) -> SCNNode {
    let line = lineFrom(vector: origin, toVector: destination)
    let lineNode = SCNNode(geometry: line)
    let planeMaterial = SCNMaterial()
    planeMaterial.diffuse.contents = color
    line.materials = [planeMaterial]
    
    return lineNode
  }
  
  private func lineFrom(vector vector1: SCNVector3, toVector vector2: SCNVector3) -> SCNGeometry {
    let indices: [Int32] = [0, 1]
    let source = SCNGeometrySource(vertices: [vector1, vector2])
    let element = SCNGeometryElement(indices: indices, primitiveType: .line)
    return SCNGeometry(sources: [source], elements: [element])
  }
}
