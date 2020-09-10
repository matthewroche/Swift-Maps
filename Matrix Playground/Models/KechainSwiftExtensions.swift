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
    
    /// clearAllForPrefix
    /// Clears all properties stored in keychain with the specified prefix
    /// - Parameter prefix: A String describing the prefix of the properties to clear from Keychain
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
