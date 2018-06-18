//
//  Action.swift
//  ARKitVision
//
//  Created by Sonam Dhingra on 6/14/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import UIKit


enum Action {
    
    case gameAction(GameAction)
    case positionAction(PositionGameAction)
    
    private enum CodingKeys: CodingKey, CaseIterable {
        case gameAction
        case positionAction
    }
}


extension Action: CustomStringConvertible {
    var description: String {
        switch self {
        case let .gameAction(gameAction): return "game action \(gameAction.identifier)"
        case let .positionAction(positionAction): return "position action \(positionAction.identifier)"
        }
    }
}
