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

public class LocationLogic: ObservableObject {
    
    init() {}
    
    var locationRequest: LocationRequest?
    @Published var currentLocation: CLLocation?
    
    func startTrackingLocation() -> Promise<Bool> {
        return Promise { resolve, reject in
            async {
                guard (self.locationRequest == nil) else {resolve(true); return}
                LocationManager.shared.requireUserAuthorization(.always)
                print("startTrackingLocation")
                self.currentLocation = try await(self.returnCurrentLocation())
                self.locationRequest = LocationManager.shared.locateFromGPS(.significant, accuracy: .block) { response in
                    print(response)
                    switch response {
                        case .success(let session):
                            print("Location: \(session.coordinate.latitude), \(session.coordinate.longitude)")
                            self.currentLocation = session
                            resolve(true)
                        case .failure(let error):
                            print(error)
                            reject(error)
                        }
                }
            }.onError {error in
                reject(error)
            }
            
        }
    }
    
    func stopTrackingLocation() -> Void {
        guard locationRequest != nil else {return}
        locationRequest!.stop()
        locationRequest = nil
    }
    
    func returnCurrentLocation() -> Promise<CLLocation> {
        return Promise { resolve, reject in
            let _ = LocationManager.shared.locateFromGPS(.oneShot, accuracy: .block) { response in
                switch response {
                    case .success(let session):
                        print("Location: \(session.coordinate.latitude), \(session.coordinate.longitude)")
                        self.currentLocation = session
                        resolve(session)
                    case .failure(let error):
                        print(error)
                        reject(error)
                }
            }
        }
    }
    
}
