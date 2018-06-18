//
//  ViewController.swift
//  MultiPlayersandbox
//
//  Created by Sonam Dhingra on 6/15/18.
//  Copyright © 2018 Sonam Dhingra. All rights reserved.
//

import UIKit
import SceneKit
import ARKit
import MultipeerConnectivity
import SnapKit

class ViewController: UIViewController, ARSCNViewDelegate {

    @IBOutlet var sceneView: ARSCNView!
    var planes = [OverlayPlane]()
    
    let multiPeerHandler = MultiPeerHandler(serviceID: "test", isHost: false)
    let activityIndicator = UIActivityIndicatorView(frame: .zero)
    
    
    var targetWorldMap: ARWorldMap?
    
    private lazy var worldMapStatusLabel :UILabel = {
        
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = .orange
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    private lazy var sendMapFeedbackLabel :UILabel = {
        let label = UILabel()
        label.textAlignment = .center
        label.textColor = .white
        label.backgroundColor = .red
        label.translatesAutoresizingMaskIntoConstraints = false
        return label
    }()
    
    
    private lazy var sendWorldMapButton :UIButton = {
        
        let button = UIButton(type: .custom)
        button.setTitle("Send World", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor.white
        button.backgroundColor = UIColor(red: 53/255, green: 73/255, blue: 94/255, alpha: 1)
        return button
        
    }()
    
    private lazy var hostButton :UIButton = {
        
        let button = UIButton(type: .custom)
        button.setTitle("Host", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = .white
        button.backgroundColor = .purple
        return button
        
    }()
    
    private lazy var joinButton :UIButton = {
        
        let button = UIButton(type: .custom)
        button.setTitle("Join", for: .normal)
        button.translatesAutoresizingMaskIntoConstraints = false
        button.tintColor = UIColor.white
        button.backgroundColor = UIColor(red: 53/255, green: 73/255, blue: 94/255, alpha: 1)
        return button
        
    }()
    
    
    private var isHost: Bool = false {
        didSet {
            sendWorldMapButton.isHidden = false
            sendMapFeedbackLabel.isHidden = false
            sendMapFeedbackLabel.text = "Wait until you see MAPPED"
            joinButton.isHidden = true
        }
    }
    
    
    private var isParticipant: Bool = false {
        didSet {
            if isParticipant == true {
                hostButton.isHidden = true
            }
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.sceneView.debugOptions = [ARSCNDebugOptions.showFeaturePoints,ARSCNDebugOptions.showWorldOrigin]
        
        // Set the view's delegate
        sceneView.delegate = self
        
        // Show statistics such as fps and timing information
        sceneView.showsStatistics = true
        
        self.sceneView.autoenablesDefaultLighting = true
        
        let scene = SCNScene()
        
        setupUI()
        registerGestureRecognizers()
        
        // Set the scene to the view
        sceneView.scene = scene
        
        sceneView.session.delegate = self
        registerMultiPeerCallbacks()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        // Create a session configuration
        let configuration = ARWorldTrackingConfiguration()
        

        configuration.planeDetection = .horizontal
        configuration.initialWorldMap = targetWorldMap
        
        // Run the view's session
        sceneView.session.run(configuration)
    }
    
    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        sendWorldMapButton.layer.cornerRadius = sendWorldMapButton.frame.width/2
    }
    
    private func setupUI() {
        
        self.view.addSubview(self.worldMapStatusLabel)
        self.view.addSubview(self.sendWorldMapButton)
        self.view.addSubview(self.activityIndicator)
        self.view.addSubview(self.hostButton)
        self.view.addSubview(self.joinButton)
        self.view.addSubview(self.sendMapFeedbackLabel)
        
        
        //add constraints to label
        
        worldMapStatusLabel.snp.makeConstraints { (make) in
            make.right.equalTo(view.snp.right).offset(-20)
            make.width.equalTo(120)
            make.height.equalTo(50)
            make.top.equalTo(view.snp.top).offset(30)
        }
        
        sendWorldMapButton.snp.makeConstraints { (make) in
            make.centerX.equalTo(view.snp.centerX)
            make.bottom.equalTo(view.snp.bottom).offset(-60)
            make.width.height.equalTo(100)
        }
        
        sendWorldMapButton.setTitleColor(.lightGray, for: .highlighted)
        sendWorldMapButton.addTarget(self, action: #selector(sendWorldMap), for: .touchUpInside)
        
        self.hostButton.snp.makeConstraints { (make) in
            make.left.equalTo(view.snp.left).offset(20)
            make.bottom.equalTo(view.snp.bottom).offset(-20)
            make.width.equalTo(view.snp.width).dividedBy(3.0)
            make.height.equalTo(60)
        }
        
        self.joinButton.snp.makeConstraints { (make) in
            make.right.equalTo(view.snp.right).offset(-20)
            make.bottom.equalTo(view.snp.bottom).offset(-20)
            make.width.equalTo(view.snp.width).dividedBy(3.0)
            make.height.equalTo(60)
        }
        
        hostButton.addTarget(self, action: #selector(didTapHost), for: .touchUpInside)
        joinButton.addTarget(self, action: #selector(didTapJoin), for: .touchUpInside)
        
        self.activityIndicator.snp.makeConstraints { (make) in
            make.center.equalTo(view.center)
            make.width.height.equalTo(50)
        }
      
        sendMapFeedbackLabel.snp.makeConstraints { (make) in
            make.left.equalTo(view.snp.left).offset(20)
            make.top.equalTo(view.snp.top).offset(30)
            make.right.equalTo(worldMapStatusLabel.snp.left).offset(10.0)
            make.height.equalTo(60)
        }
        
        sendMapFeedbackLabel.isHidden = true
        
        hostButton.setTitleColor(.lightGray, for: .highlighted)
        joinButton.setTitleColor(.lightGray, for: .highlighted)
        
        sendWorldMapButton.isHidden = true
        sendWorldMapButton.isEnabled = false
    }
    
    
    private func registerGestureRecognizers() {
        let tapGestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(didTapScreen(sender:)))
        self.sceneView.addGestureRecognizer(tapGestureRecognizer)
    }
    
    @objc func didTapScreen(sender: UIGestureRecognizer) {
        
    }
    
    @objc func didTapHost() {
        isHost = true
        multiPeerHandler.host(with: nil)        
    }
    
    @objc func didTapJoin() {
        isParticipant = true
        let mcBrowser = multiPeerHandler.joinSessionAndRtrnBrowser()
        mcBrowser.delegate = self
        present(mcBrowser, animated: true, completion: nil)
    }
    
    
    
    @objc func sendWorldMap() {
        multiPeerHandler.sendWorldMap(from: self.sceneView, withInitial: targetWorldMap) { worldMapStatus in
            switch worldMapStatus {
            case let .failure(error): print("could not send the world map \(error)")
            case .success: print("world map sent!" )
            }
        }
    }
    
    /// TAG: -  Delegate
    
    func renderer(_ renderer: SCNSceneRenderer, didAdd node: SCNNode, for anchor: ARAnchor) {
        
        if !(anchor is ARPlaneAnchor) {
            return
        }
        
        let plane = OverlayPlane(anchor: anchor as! ARPlaneAnchor)
        self.planes.append(plane)
        node.addChildNode(plane)
        
        // add a virtual object
        guard let beeScene = SCNScene(named: "art.scnassets/bee.dae"),
            let beeNode = beeScene.rootNode.childNode(withName: "bee_root", recursively: true) else {
                print("could not get the bee node")
                return
        }
        
        node.addChildNode(beeNode)
    }
    
    func renderer(_ renderer: SCNSceneRenderer, didUpdate node: SCNNode, for anchor: ARAnchor) {
        
        let plane = self.planes.filter { plane in
            return plane.anchor.identifier == anchor.identifier
            }.first
        
        if plane == nil {
            return
        }
        
        plane?.update(anchor: anchor as! ARPlaneAnchor)
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // Pause the view's session
        sceneView.session.pause()
    }
    
    
    
    func registerMultiPeerCallbacks() {
        
        multiPeerHandler.onDidReceiveData = { (data, displayName) in
            
            if let unarchivedAnchor = try? NSKeyedUnarchiver.unarchivedObject(of: ARAnchor.classForKeyedUnarchiver(), from: data) {
                
            } 
            
            
            print("recieved data from \(displayName) with \(data.debugDescription)")
            //self.showBee()
        }
        
        multiPeerHandler.onConnectedToANewPlayer = { isNewPlayer in
           // self.multiPeerHandler.sendWorldMap(from: self.sceneView, withInitial: self.targetWorldMap)
        }
        
        
        multiPeerHandler.onDidReceiveWorldMap = { worldMap in
            if self.isParticipant {
                // Run the session with the received world map.
                DispatchQueue.main.async {
                    let configuration = ARWorldTrackingConfiguration()
                    configuration.planeDetection = .horizontal
                    configuration.initialWorldMap = worldMap
                    self.sceneView.session.run(configuration, options: [.resetTracking, .removeExistingAnchors])
                }
            }
        }
    }
    
        
}
    
    
extension ViewController: ARSessionDelegate {
    
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        
        switch frame.worldMappingStatus {
        case .notAvailable:
            self.worldMapStatusLabel.text = "NOT AVAILABLE"
        case .limited:
            self.worldMapStatusLabel.text = "LIMITED"
        case .extending:
            self.worldMapStatusLabel.text = "EXTENDING"
        case .mapped:
            self.worldMapStatusLabel.text = "MAPPED"
            if isHost == true {
                sendMapFeedbackLabel.text = "You can send it!"
                sendWorldMapButton.isEnabled = true
            }
        }
        
    }
}


extension ViewController: MCBrowserViewControllerDelegate {
    
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


public extension Float {
    /// SwiftRandom extension
    public static func random(lower: Float = 0, _ upper: Float = 100) -> Float {
        return (Float(arc4random()) / 0xFFFFFFFF) * (upper - lower) + lower
    }
}


extension SCNVector4 {
    init(_ vector: float4) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: vector.w)
    }
    
    init(_ vector: SCNVector3) {
        self.init(x: vector.x, y: vector.y, z: vector.z, w: 1)
    }
}

extension float4x4 {
    init(_ matrix: SCNMatrix4) {
        self.init([
            float4(matrix.m11, matrix.m12, matrix.m13, matrix.m14),
            float4(matrix.m21, matrix.m22, matrix.m23, matrix.m24),
            float4(matrix.m31, matrix.m32, matrix.m33, matrix.m34),
            float4(matrix.m41, matrix.m42, matrix.m43, matrix.m44)
            ])
    }
}

