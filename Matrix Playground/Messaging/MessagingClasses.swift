//
//  MessagingClasses.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 04/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import CoreLocation

class DirectMessage: Codable {
    
    init(_ location: CLLocation) throws {
        self.location = [location.coordinate.latitude, location.coordinate.longitude]
    }
    init(_ dictionary: [String: Any]) throws {
        let data = try JSONDecoder().decode(DirectMessage.self, from: JSONSerialization.data(withJSONObject: dictionary))
        self.location = data.location
    }
    init(_ string: String) throws {
        let data = try JSONDecoder().decode(DirectMessage.self, from: string.data(using: .utf8)!)
        self.location = data.location
    }
    
    var location: [Double]
    
    func toDictionary() -> NSDictionary {
        let locationDictionary: NSDictionary = [
            "location": self.location
        ]
        return locationDictionary
    }
    
    func toJSONString() throws -> String {
        return String(data: try JSONEncoder().encode(self), encoding: .utf8) ?? ""
    }
}
