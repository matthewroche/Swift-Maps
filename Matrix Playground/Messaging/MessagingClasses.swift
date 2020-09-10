//
//  MessagingClasses.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 04/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import CoreLocation

/// MatrixMapsMessage
/// A class describing the context of the final message structure used internally by MatrixMaps once decryption has been performed
/// Handles conversion to/from JSON string and dictionary
class MatrixMapsMessage: Codable {
    
    var location: [Double]
    var version: Int?
    
    /// init
    ///  Initialise using location and version strings
    /// - Parameters:
    ///   - location: A CLLocation to be stored in the message
    ///   - version: An Int describing the message version (optional)
    init(_ location: CLLocation, version: Int? = nil) {
        self.location = [location.coordinate.latitude, location.coordinate.longitude]
        self.version = version
    }
    /// init
    /// Initialise from a dictionary
    /// - Parameter dictionary: A dictionary from which to construct the MatrixMapsMessage
    init(_ dictionary: [String: Any]) throws {
        let data = try JSONDecoder().decode(MatrixMapsMessage.self, from: JSONSerialization.data(withJSONObject: dictionary))
        self.location = data.location
        self.version = data.version ?? nil
    }
    /// init
    /// Initialise from JSON string
    /// - Parameter string: A JSON string from which to construct the MatrixMapsMessage
    init(_ string: String) throws {
        let data = try JSONDecoder().decode(MatrixMapsMessage.self, from: string.data(using: .utf8)!)
        self.location = data.location
        self.version = data.version ?? nil
    }
    
    /// toDictionary
    /// Converts the MatrixMApsMessage to an NSDictionary object
    /// - Returns: NSDictionary representing the MatrixMapsMessage
    func toDictionary() -> NSDictionary {
        if self.version != nil {
            return NSDictionary(dictionary: [
                "location": self.location,
                "version": self.version as Any
            ])
        } else {
            return NSDictionary(dictionary: [
                "location": self.location
            ])
        }
    }
    
    /// toJSONString
    /// Converts the MatrixMapsMessage to a JSON string
    /// - Returns: A String describing the MatrixMapsMessage in JSON form
    func toJSONString() throws -> String {
        return String(data: try JSONEncoder().encode(self), encoding: .utf8) ?? ""
    }
}
