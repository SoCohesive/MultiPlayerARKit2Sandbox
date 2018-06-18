//
//  MultiPeerHandler.swift
//  ARKitVision
//
//  Created by Sonam Dhingra on 6/12/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import MultipeerConnectivity
import ARKit
import os.signpost
import simd


enum MessageStatus {
    case success
    case failure(Error)
}

enum WorldMapResult {
    case success(ARWorldMap)
    case error
}

typealias PeerEventCallback = (_ displayName: String) -> Void
typealias MessageStatusCallback = (_ result: MessageStatus) -> Void
typealias MessageReceivedCallback = (_ result: Data, _ peerID: String) -> Void
typealias WorldMapCallBack = (_ result: WorldMapResult) -> Void

typealias EmptyCallback = () -> Void


protocol MultiPeerHandlingDelegate: class {
    
    func onDidReceive(_ gameAction: GameActionType, from player: Player)
    func onWorldMapReceived(_ worldMap: ARWorldMap, from player: Player)
    func onSentMessageStatus(_ status: MessageStatus)
    func onPlayerJoined(with info: Player)
    func onStateChangedToConnecting()
    func onStateChangedToNotConnected()
}

protocol MultipeerHandling {
    
    var peerID: MCPeerID { get }
    var mcSession: MCSession { get }
    var mcAdvertiserAssistant: MCNearbyServiceAdvertiser? { get }
    var serviceID: String { get }
    var isNetworked: Bool { get }
    var isServer: Bool { get set }
    var delegate: MultiPeerHandlingDelegate? { get set }

    
    // Host/Join
    func host(with discoveryInfo: [String: String]?)
    func joinSessionAndRtrnBrowser() -> MCBrowserViewController
    
    // Send
    func send(_ gameAction: GameActionType?, or data: Data?, toEveryone everyone: Bool, with result: @escaping MessageStatusCallback)
    
    // Callbacks or use the delegated
    var onStateChangedToConnected: PeerEventCallback? { get set }
    var onStateChangedToNotConnected: PeerEventCallback? { get set }
    var onStateChangedToConnecting: PeerEventCallback? { get set }
    var onDidStartAdvertising: EmptyCallback? { get set }
    var onDidReceiveData: MessageReceivedCallback? { get set }
    var onConnectedToANewPlayer: ((Bool) -> Void)? { get set }
}


protocol ARMultipeerHandling: MultipeerHandling {
    
    var worldUtitiliy: WorldMapExtractor { get }
    func sendWorldMap(from scene: ARSCNView, withInitial initialWorldMap: ARWorldMap?, monitoring statusCallback: @escaping MessageStatusCallback)
    func syncPhysics()
    func loadWorldMap(from archivedData: Data, with callBack: WorldMapCallBack?)
    var onDidReceiveWorldMap: ((ARWorldMap) -> Void)? { get set }
    
}

class MultiPeerHandler: NSObject, ARMultipeerHandling {
    
    var onStateChangedToConnected: PeerEventCallback?
    var onStateChangedToNotConnected: PeerEventCallback?
    var onStateChangedToConnecting: PeerEventCallback?
    var onDidReceiveData: MessageReceivedCallback?
    var onDidStartAdvertising: EmptyCallback?
    var onConnectedToANewPlayer: ((Bool) -> Void)?
    var onDidReceiveWorldMap: ((ARWorldMap) -> Void)?
    
    let peerID = MCPeerID(displayName: UIDevice.current.name)
    let mcSession: MCSession
    var mcAdvertiserAssistant: MCNearbyServiceAdvertiser?
    let serviceID: String
    let isNetworked: Bool
    var isServer: Bool

    let worldUtitiliy = WorldMapExtractor()
    var peers = [Player]()
    
    weak var delegate: MultiPeerHandlingDelegate?
    
    
    private lazy var encoder: PropertyListEncoder = {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return encoder
    }()
    
    private lazy var decoder = PropertyListDecoder()

    
    init(serviceID: String, isHost: Bool) {
        self.serviceID = serviceID
        self.mcSession = MCSession(peer: peerID, securityIdentity: nil, encryptionPreference: .none) // Todo: (SD) - Add property for developer to set security identity and encryption preference
        
        self.isServer = isHost
        self.isNetworked = !isHost
        
        super.init()
        mcSession.delegate = self
    }
    
    @available(iOS 12.0, *)
    
    func sendWorldMap(from scene: ARSCNView, withInitial initialWorldMap: ARWorldMap?, monitoring statusCallback: @escaping MessageStatusCallback) {
        
        worldUtitiliy.getCurrentWorldMapData(for: scene, with: initialWorldMap) { (data, error) in
            guard let safeData = data else {
                assertionFailure("Could not get the world map")
                return
            }
            
            // now send the world map
            self.send(nil, or: safeData, with: { (status) in
                statusCallback(status)
            })
    
        }
    }
    
    func send(_ gameAction: GameActionType?, or data: Data?, toEveryone everyone: Bool = false, with result: @escaping MessageStatusCallback) {
        

        if mcSession.connectedPeers.count > 0 {
            do {
                
                // REALLY BAD AND UGLY!
                var gameActionData: Data?
                switch gameAction {
                    
                case is GameAction:
                    let genericGameAction = gameAction as! GameAction
                    guard let safeData = try? JSONEncoder().encode(genericGameAction) else {
                        print("could not enfcode the game action")
                        return
                    }
                    gameActionData = safeData
                    
                case is PositionGameAction:
                    let positionAction = gameAction as! PositionGameAction
                    guard let safeData = try? JSONEncoder().encode(positionAction) else {
                        print("could not enfcode the position action")
                        return
                    }
                    
                    gameActionData = safeData
                    
                default:
                    break
                }
            
        
                //bad!!!
                try mcSession.send(gameActionData != nil ? gameActionData! : data!, toPeers: mcSession.connectedPeers, with: .reliable)
                result(.success)
            } catch let error {
                result(MessageStatus.failure(error))
            }
        }
    }
    
    
    func syncPhysics() {
        // TODO
        
    }
    
    // aka advertise
    func host(with discoveryInfo: [String : String]?) {
        self.isServer = true
        mcAdvertiserAssistant = MCNearbyServiceAdvertiser(peer: peerID, discoveryInfo: discoveryInfo, serviceType: serviceID)
        
        mcAdvertiserAssistant?.delegate = self
        mcAdvertiserAssistant?.startAdvertisingPeer()
        onDidStartAdvertising?()
    }
    
    
    func stopAdvertising() {
        mcAdvertiserAssistant?.stopAdvertisingPeer()
        mcAdvertiserAssistant = nil
    }

    
    func joinSessionAndRtrnBrowser() -> MCBrowserViewController {
        let mcBrowser = MCBrowserViewController(serviceType: serviceID, session: mcSession)
        return mcBrowser
    }
    
    /*func send(action: Action, to player: Player) {
        do {
            var bits = WritableBitStream()
            try action.encode(to: &bits)
            let data = bits.packData()
            if data.count > 10_000 {
                try sendLarge(data: data, to: player.peerID)
            } else {
                try sendSmall(data: data, to: player.peerID)
            }
            if action.description != "physics" {
                os_signpost(type: .event, log: .network_data_sent, name: .network_action_sent, signpostID: .network_data_sent,
                            "Action : %s", action.description)
            } else {
                let bytes = Int32(exactly: data.count) ?? Int32.max
                os_signpost(type: .event, log: .network_data_sent, name: .network_physics_sent, signpostID: .network_data_sent,
                            "%d Bytes Sent", bytes)
            }
        } catch {
            log.error("sending failed: \(error)")
        }
    }
    

    func sendLarge(data: Data, to peer: MCPeerID) throws {
        let fileName = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent(UUID().uuidString)
        try data.write(to: fileName)
        session.sendResource(at: fileName, withName: "Action", toPeer: peer) { error in
            if let error = error {
                log.error("sending failed: \(error)")
                return
            }
            print("send succeeded, removing temp file")
            do {
                try FileManager.default.removeItem(at: fileName)
            } catch {
                log.error("removing failed: \(error)")
            }
        }
    }

    
    //Physics ?
    func syncPhysics() {
        os_signpost(type: .begin, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
                    "Physics sync started")
        if isNetworked && physicsSyncData.isInitialized {
            if isServer {
                let physicsData = physicsSyncData.generateData()
                session?.send(action: .physics(physicsData))
            } else {
                physicsSyncData.updateFromReceivedData()
            }
        }
        os_signpost(type: .end, log: .render_loop, name: .physics_sync, signpostID: .render_loop,
                    "Physics sync finished")
        
    }
     */
    private let log = Log()
    
    /// Load the World Map from archived data
    func loadWorldMap(from archivedData: Data, with result: WorldMapCallBack?) {
        
        if
            let unarchived = try? NSKeyedUnarchiver.unarchivedObject(of: ARWorldMap.classForKeyedUnarchiver(), from: archivedData),
            let worldMap = unarchived as? ARWorldMap {
            
            result?(.success(worldMap))
            
        } else {
            result?(.error)
        }
    }

    
    // Recieving
    
    func receive(data: Data, from peerID: MCPeerID) {
        let player = Player(peerID: peerID)
        peers.contains(player) == false ? peers.append(player) : ()
        
        // Try world map first...
        // p.s - this is ugly atm
        loadWorldMap(from: data, with: { (result) in
            print("result \(result)")
            
            switch result {
            case let .success(worldMap):
                self.delegate?.onWorldMapReceived(worldMap, from: player)
            case .error:
                if let potentialGameAction = self.transformDataToGameAction(from: data, with: peerID) {
                    self.delegate?.onDidReceive(potentialGameAction, from: player)
                } else {
                    print("error receiving data")
                }
            }
        })

    }
    
    func  transformDataToGameAction(from data: Data, with peerID: MCPeerID) -> GameActionType? {
        
        // so ugly , loop in an enum and make the enum the codable type
        if let genericGameAction = try? JSONDecoder().decode(GameAction.self, from: data) {
            return genericGameAction
        } else if let positionGameAction = try? JSONDecoder().decode(PositionGameAction.self, from: data) {
            return positionGameAction
        }
        
        return nil
    }
}
    

extension MultiPeerHandler: MCAdvertiserAssistantDelegate {
    func advertiserAssistantWillPresentInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
        
    }
    
    func advertiserAssistantDidDismissInvitation(_ advertiserAssistant: MCAdvertiserAssistant) {
        
    }
}

extension MultiPeerHandler: MCSessionDelegate {
    
    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        
        print("did recieve data \(data)")
        receive(data: data, from: peerID)
        onDidReceiveData?(data, peerID.displayName) /// Recieving end of this should do any UI work on the main queue ***
    }
    
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        
        var isNewPlayer: Bool
        let player = Player(peerID: peerID)
        isNewPlayer = peers.contains(player) == false
            
        peers.append(player)
        
        switch state {
        case .connected:
            print("Connected: \(peerID.displayName)")
            delegate?.onPlayerJoined(with: player)
        case .connecting:
            print("Connecting: \(peerID.displayName)")
            delegate?.onStateChangedToConnecting()
            onStateChangedToConnecting?(peerID.displayName)
        case .notConnected:
            print("Not connected: \(peerID.displayName)")
            delegate?.onStateChangedToNotConnected()
            onStateChangedToNotConnected?(peerID.displayName)
        }
    }
    
    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {
        
    }
    
    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {
        
    }
    
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID, certificateHandler: @escaping (Bool) -> Void) {
        
        certificateHandler(true)
    }
    
    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {
        if let error = error {
            print("failed to receive resource: \(error)")
            return
        }
        guard let url = localURL else { print("what what no url?"); return }
        
        do {
            // .mappedIfSafe makes the initializer attempt to map the file directly into memory
            // using mmap(2), rather than serially copying the bytes into memory.
            // this is faster and our app isn't charged for the memory usage.
            let data = try Data(contentsOf: url, options: .mappedIfSafe)
            receive(data: data, from: peerID)
            // removing the file is done by the session, so long as we're done with it before the
            // delegate method returns.
        } catch {
            print("dealing with resource failed: \(error)")
        }
    }
}

extension MultiPeerHandler: MCNearbyServiceAdvertiserDelegate {
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                    didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?,
                    invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        
        DispatchQueue.main.async {            
            invitationHandler(true, self.mcSession)
        }
    }
    
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        print("did not start advertising with peer \(error.localizedDescription)")
    }
}
