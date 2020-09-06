//
//  RootState.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 19/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum RootStates {
    case loggedIn
    case loggedOut
}

class RootState: ObservableObject {
    @Published var state: RootStates = .loggedOut
}
