//
//  WorldMapExtractor.swift
//  ARKitVision
//
//  Created by Sonam Dhingra on 6/13/18.
//  Copyright © 2018 Apple. All rights reserved.
//

import Foundation
import ARKit
import MachO

class WorldMapExtractor {
    
    @available(iOS 12.0, *)
    public func getCurrentWorldMapData(for sceneView: ARSCNView, with initialWorldMap: ARWorldMap?, _ closure: @escaping (Data?, Error?) -> Void) {
        
        // When loading a map, send the loaded map and not the current extended map
        if let targetWorldMap = initialWorldMap {
            compressMap(map: targetWorldMap, closure)
            return
        } else {

            sceneView.session.getCurrentWorldMap { map, error in
                if let error = error {
                    print("didn't work! \(error)")
                    closure(nil, error)
                }
                guard let map = map else { print("no map either!"); return }
                print("got a worldmap, compressing it")
                self.compressMap(map: map, closure)
            }
        }
    }
    
    @available(iOS 12.0, *)
    private func compressMap(map: ARWorldMap, _ closure: @escaping (Data?, Error?) -> Void) {
        DispatchQueue.global().async {
            do {
                let data = try NSKeyedArchiver.archivedData(withRootObject: map, requiringSecureCoding: true)
                print("data size is \(data.count)")
                //let compressedData = data.compressed()
                //print("compressed size is \(compressedData.count)")
                closure(data, nil)
            } catch {
                print("archiving failed \(error)")
                closure(nil, error)
            }
        }
    }
}
