//
//  IdentifiableError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 25/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

public struct IdentifiableError: Identifiable {
    public let id = UUID()
    let error: Error
    
    init(_ error: Error) {
        self.error = error
    }
}
