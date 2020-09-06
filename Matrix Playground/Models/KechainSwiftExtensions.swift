//
//  KechainSwiftExtensions.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 31/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import KeychainSwift

public extension KeychainSwift {
    
    func clearAllForPrefix(_ prefix: String) {
        
        for key in self.allKeys {
            if key.contains(prefix) {
                let shortenedKeyName = key.replacingOccurrences(of: prefix, with: "")
                self.delete(shortenedKeyName)
                self.delete(key)
            }
        }
        
    }
    
}
