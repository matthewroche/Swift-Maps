//
//  LocationLogic.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 24/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftLocation
import CoreLocation
import Then

/// Contains the logic for storing location and starting / stopping background location tracking
public class LocationLogic: ObservableObject {
    
    private var locationRequest: LocationRequest?
    @Published var currentLocation: CLLocation?
    
    /// startTrackingLocation
    /// Sets a LocationRequest up and tracks the location in the background, updating currentLocation appropriately
    /// - Returns: A promise reolving to true once the first update to currentLocation completes.
    func startTrackingLocation() -> Promise<Bool> {
        return Promise { resolve, reject in
            async {
                print("startTrackingLocation")
                guard (self.locationRequest == nil) else {resolve(true); return}
                LocationManager.shared.requireUserAuthorization(.always)
                let currentLocation = try await(self.returnCurrentLocation())
                DispatchQueue.main.async {
                    self.currentLocation = currentLocation
                }
                self.locationRequest = LocationManager.shared.locateFromGPS(.continous, accuracy: .room) { response in
                    print("New location received")
                    print(self.locationRequest ?? "Location Request = Nil")
                    switch response {
                        case .success(let session):
                            DispatchQueue.main.async {
                                self.currentLocation = session
                            }
                        case .failure(let error):
                            print(error)
                            reject(error)
                    }
                }
                resolve(true)
            }.onError {error in
                reject(error)
            }
            
        }
    }
    
    /// stopTrackingLocation
    /// Stops the current locationRequest
    /// - Returns: Void
    func stopTrackingLocation() -> Void {
        print("Stopping location tracking")
        guard self.locationRequest != nil else {return}
        DispatchQueue.main.async {
            self.locationRequest!.stop()
            self.locationRequest = nil
        }
    }
    
    /// Returns the current location as a one-shot request, no background tracking is initiated.
    /// - Returns: A Promise resolving to a CLLocation on success
    func returnCurrentLocation() -> Promise<CLLocation> {
        return Promise { resolve, reject in
            let _ = LocationManager.shared.locateFromGPS(.oneShot, accuracy: .block) { response in
                switch response {
                    case .success(let session):
                        print("Location: \(session.coordinate.latitude), \(session.coordinate.longitude)")
                        resolve(session)
                    case .failure(let error):
                        print(error)
                        reject(error)
                }
            }
        }
    }
    
}
