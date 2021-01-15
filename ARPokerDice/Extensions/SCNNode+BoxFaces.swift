//
//  SCNNode+BoxFaces.swift
//  ARPokerDice
//
//  Created by Aleksei Sobolevskii on 2021-01-13.
//  Copyright © 2021 Alexey Sobolevsky. All rights reserved.
//

import SceneKit

enum BoxFace: Int {
    case front, right, back, left, top, bottom
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
