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
        // The view will always have one addional annotation when compared to our
        // annotations array, as it includes the local user's location
        if (annotations.count + 1) != view.annotations.count {
            view.removeAnnotations(annotations)
            view.addAnnotations(annotations)
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

