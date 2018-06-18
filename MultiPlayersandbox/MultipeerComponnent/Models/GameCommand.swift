/*
 See LICENSE folder for this sample’s licensing information.
 
 Abstract:
 Representations for game events, related data, and their encoding.
 */

import Foundation
import simd


protocol GameActionType: Codable {
    var identifier: String { get }
}

struct GameAction: GameActionType {
    let identifier: String
}

struct PositionGameAction: GameActionType {
    let identifier: String // Use node name 
    let x: Float
    let y: Float
    let z: Float
}



// TODO -> Decode the enums attached to this struct for dev to use
/// - Tag: GameCommand
struct GameCommand     {
    var player: Player?
    var action: Action
}

extension float3: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        self.init(x, y, z)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
    }
}

extension float4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let x = try bitStream.readFloat()
        let y = try bitStream.readFloat()
        let z = try bitStream.readFloat()
        let w = try bitStream.readFloat()
        self.init(x, y, z, w)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        bitStream.appendFloat(x)
        bitStream.appendFloat(y)
        bitStream.appendFloat(z)
        bitStream.appendFloat(w)
    }
}

extension float4x4: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        self.init()
        self.columns.0 = try float4(from: &bitStream)
        self.columns.1 = try float4(from: &bitStream)
        self.columns.2 = try float4(from: &bitStream)
        self.columns.3 = try float4(from: &bitStream)
    }
    
    func encode(to bitStream: inout WritableBitStream) {
        columns.0.encode(to: &bitStream)
        columns.1.encode(to: &bitStream)
        columns.2.encode(to: &bitStream)
        columns.3.encode(to: &bitStream)
    }
}

extension String: BitStreamCodable {
    init(from bitStream: inout ReadableBitStream) throws {
        let data = try bitStream.readData()
        if let value = String(data: data, encoding: .utf8) {
            self = value
        } else {
            throw BitStreamError.encodingError
        }
    }
    
    func encode(to bitStream: inout WritableBitStream) throws {
        if let data = data(using: .utf8) {
            bitStream.append(data)
        } else {
            throw BitStreamError.encodingError
        }
    }
}


