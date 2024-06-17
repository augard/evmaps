//
//  VehicleResponse.swift
//  KiaMaps
//
//  Created by Lukas Foldyna on 31.05.2024.
//  Copyright © 2024 Lukas Foldyna. All rights reserved.
//

import Foundation

struct VehicleResponse: Decodable {
    let vehicles: [Vehicle]
}

struct Vehicle: Decodable, Identifiable {
    let vin: String
    let type: VehicleType
    let vehicleId: UUID
    let vehicleName: String
    let nickname: String
    let tmuNumber: String
    let year: String
    let registrationDate: Date
    let master: Bool
    let carShare: Int
    let personalFlag: String
    let detailInfo: DetailInfo
    let protocolType: Int
    @BoolValue private(set) var ccuCCS2ProtocolSupport: Bool
    
    var id: UUID { vehicleId }
    
    enum CodingKeys: String, CodingKey {
        case vin
        case type
        case vehicleId
        case vehicleName
        case nickname
        case tmuNumber = "tmuNum"
        case year
        case registrationDate = "regDate"
        case master
        case carShare
        case personalFlag
        case detailInfo
        case protocolType
        case ccuCCS2ProtocolSupport
    }
    
    struct DetailInfo: Decodable {
        let bodyType: String
        let interiorColor: String
        let outsideColor: String
        let saleCarmdlCd: String
        let saleCarmdlEnName: String
        
        enum CodingKeys: String, CodingKey {
            case bodyType
            case interiorColor = "inColor"
            case outsideColor = "outColor"
            case saleCarmdlCd
            case saleCarmdlEnName = "saleCarmdlEnNm"
        }
    }
}

extension Array where Element == Vehicle {
    func vehicle(with vin: String?) -> Vehicle? {
        guard let vin = vin?.uppercased() else { return nil }
        return first(where: { $0.vin == vin })
    }
}
