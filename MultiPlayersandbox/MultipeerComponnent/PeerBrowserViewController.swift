//
//  PeerBrowserViewController.swift
//  ARKitVision
//
//  Created by Sonam Dhingra on 6/12/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import UIKit
import MultipeerConnectivity

class PeerBrowserViewController: MCBrowserViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()

    }
}


extension PeerBrowserViewController: MCBrowserViewControllerDelegate {
    
    func browserViewControllerDidFinish(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
    func browserViewController(_ browserViewController: MCBrowserViewController, shouldPresentNearbyPeer peerID: MCPeerID, withDiscoveryInfo info: [String : String]?) -> Bool {
        return true
    }
    
    func browserViewControllerWasCancelled(_ browserViewController: MCBrowserViewController) {
        dismiss(animated: true, completion: nil)
    }
    
}
