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

/// Represents a vehicle from the API response containing vehicle identification,
/// specifications, and configuration details. This structure maps directly to the
/// vehicle objects returned in the vehicles array from the API.
///
/// Example API response structure:
/// ```json
/// {
///   "vehicles": [
///     {
///       "vin": "KMHL14JA5PA123456",
///       "type": "EV",
///       "vehicleId": "12345678-1234-1234-1234-123456789012",
///       "vehicleName": "Genesis GV60 Performance AWD",
///       "nickname": "My Genesis",
///       "tmuNum": "TMU123456789",
///       "year": "2023",
///       "regDate": "2024-05-16 11:52:59.116",
///       "master": true,
///       "carShare": 1,
///       "personalFlag": "Y",
///       "detailInfo": { ... },
///       "protocolType": 1,
///       "ccuCCS2ProtocolSupport": 1
///     }
///   ]
/// }
/// ```
struct Vehicle: Decodable, Identifiable {
    /// Vehicle Identification Number - unique identifier for the vehicle
    let vin: String
    
    /// Vehicle type classification (EV, HEV, PGEV, GN, FCEV)
    let type: VehicleType
    
    /// Unique UUID identifier for this vehicle in the system
    let vehicleId: UUID
    
    /// Full vehicle model name (e.g., "Genesis GV60 Performance AWD")
    let vehicleName: String
    
    /// User-defined nickname for the vehicle (e.g., "My Genesis")
    let nickname: String
    
    /// Telematics unit number for vehicle communication
    let tmuNumber: String
    
    /// Manufacturing year of the vehicle
    let year: String
    
    /// Vehicle registration date (parsed from timestamp)
    @DateValue<MillisecondDateFormatter> var registrationDate: Date
    
    /// Whether this is the master/primary vehicle for the user account
    let master: Bool
    
    /// Car sharing status (1 = enabled, 0 = disabled)
    let carShare: Int
    
    /// Personal flag identifier
    let personalFlag: String
    
    /// Detailed vehicle information including colors and model codes
    let detailInfo: DetailInfo
    
    /// Protocol type for vehicle communication
    let protocolType: Int
    
    /// Whether the vehicle supports CCS2 charging protocol
    @BoolValue private(set) var ccuCCS2ProtocolSupport: Bool

    var id: UUID { vehicleId }
    
    // MARK: - Computed Properties
    
    /// Whether car sharing is enabled for this vehicle
    var isCarSharingEnabled: Bool { carShare == 1 }
    
    /// Whether the vehicle supports CCS2 charging
    var supportsCCS2Charging: Bool { ccuCCS2ProtocolSupport }
    
    /// Full display name combining nickname and year
    var fullDisplayName: String { "\(nickname) (\(year))" }

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
        /// Vehicle body type classification
        let bodyType: String
        
        /// Interior color code/name
        let interiorColor: String
        
        /// Exterior color code/name
        let outsideColor: String
        
        /// Sales car model code
        let saleCarmdlCd: String
        
        /// Sales car model English name
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
