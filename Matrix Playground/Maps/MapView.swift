//
//  MapView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 20/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import MapKit
import SwiftUI

/// MapView
/// A view wrapping MKMapView handling updates to the centre coordinate and annotations
struct MapView: UIViewRepresentable {
    
    @Binding var centerCoordinate: CLLocationCoordinate2D
    var annotations: [MKPointAnnotation]
    
    /// makeUIView
    /// - Parameter context: The UIViewRepresentableContext relating to our MapView
    /// - Returns: The MKMapView described by MapView
    func makeUIView(context: UIViewRepresentableContext<MapView>) -> MKMapView {
        let mapView = MKMapView()
        // Set the delegate
        mapView.delegate = context.coordinator
        //Define the visible region
        let region = MKCoordinateRegion(
            center: centerCoordinate,
            latitudinalMeters: CLLocationDistance(exactly: 5000)!,
            longitudinalMeters: CLLocationDistance(exactly: 5000)!)
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
        mapView.showsUserLocation = true
        return mapView
    }
    
    /// updateUIView
    /// Handles updates to the MKMapView
    /// - Parameters:
    ///   - view: The MKMapView that will update
    ///   - context: The UIViewRepresentableContext relating to our MapView
    func updateUIView(_ view: MKMapView, context: UIViewRepresentableContext<MapView>) {
        // As there will only be one annotation, just update the annotation on each update
        //Get hashes of new annotations
        let newAnnotationHashes = annotations.map { annotation in
            return annotation.hash
        }
        // For each old annotation
        for annotation in view.annotations {
            // If it is not the users location
            if !(annotation is MKUserLocation) {
                // If it is not in the list of new hashes
                if !(newAnnotationHashes.contains(annotation.hash)) {
                    // Remove annotation
                    view.removeAnnotation(annotation)
                }
            }
        }
        // Get hashes of remaining annotations after removal of above
        let oldAnnotationHashes = view.annotations.map { annotation in
            return annotation.hash
        }
        // For each new annotation
        for annotation in annotations {
            // If it is not already in the existing list of annotations
            if !(oldAnnotationHashes.contains(annotation.hash)) {
                // Add annotation
                view.addAnnotation(annotation)
            }
        }
    }
    
    /// makeCoordinator
    /// Creates the Coordinator described below
    /// - Returns: The required Coordinator
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    /// Coordinator
    /// Controls the MKMapView
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        /// mapViewDidCahngeVisibleRegion
        /// Called when the map moves
        /// Updates the centreCoordinate binding
        /// - Parameter mapView: <#mapView description#>
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.centerCoordinate = mapView.centerCoordinate
        }
        
        
        /// mapView
        /// Updates the map view and creates the relevat annotations described by annotations
        /// - Parameters:
        ///   - mapView: The MKMapView that we are updating
        ///   - annotation: The annotations that need to be created
        /// - Returns: An MKAnnotationView
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                 //return nil so map view draws "blue dot" for local user location
                 return nil
            }
            // For all other annotations create a MKPinAnnotationView
            let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
            // Allow user to click on the pin for more details
            view.canShowCallout = true
            return view
        }
    }
}

