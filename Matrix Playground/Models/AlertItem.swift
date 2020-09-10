//
//  AlertItem.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 23/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftUI

/// A wrapper for the properties required to create an Alert.
struct AlertItem: Identifiable {
    var id = UUID()
    var title: Text
    var message: Text
    var primaryButton: Alert.Button
    var secondaryButton: Alert.Button?
}
