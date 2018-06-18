//
//  Player.swift
//  ARKitVision
//
//  Created by Sonam Dhingra on 6/13/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import simd

class Player: Hashable {
    
    static func == (lhs: Player, rhs: Player) -> Bool {
        return lhs.peerID == rhs.peerID
    }
    
    let hashValue: Int
    let peerID: MCPeerID
    var username: String { return peerID.displayName }
    
    init(peerID: MCPeerID) {
        self.peerID = peerID
        self.hashValue = peerID.hashValue
    }
    
    init(username: String) {
        self.peerID = MCPeerID(displayName: username)
        self.hashValue = self.peerID.hashValue
    }
}


