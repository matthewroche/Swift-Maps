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

struct MapView: UIViewRepresentable {
    
    @Binding var centerCoordinate: CLLocationCoordinate2D
    var annotations: [MKPointAnnotation]
    
    func makeUIView(context: UIViewRepresentableContext<MapView>) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        let region = MKCoordinateRegion(
            center: centerCoordinate,
            latitudinalMeters: CLLocationDistance(exactly: 5000)!,
            longitudinalMeters: CLLocationDistance(exactly: 5000)!)
        mapView.setRegion(mapView.regionThatFits(region), animated: false)
        mapView.showsUserLocation = true

        return mapView
    }

    func updateUIView(_ view: MKMapView, context:
        UIViewRepresentableContext<MapView>) {
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
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: MapView

        init(_ parent: MapView) {
            self.parent = parent
        }
        
        func mapViewDidChangeVisibleRegion(_ mapView: MKMapView) {
            parent.centerCoordinate = mapView.centerCoordinate
        }
        
        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            if annotation is MKUserLocation {
                 //return nil so map view draws "blue dot" for standard user location
                 return nil
            }
            let view = MKPinAnnotationView(annotation: annotation, reuseIdentifier: nil)
            view.canShowCallout = true
            return view
        }
    }
}

