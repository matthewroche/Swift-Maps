//
//  LoginError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 08/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum MessagingError: LocalizedError {
    case notLoggedIn
    case duplicateChat
    case noUsername
    case noDevice
}

extension MessagingError {
    public var errorDescription: String? {
        switch self {
            case .notLoggedIn:
                return NSLocalizedString("User is not logged in", comment: "")
            case .duplicateChat:
                return NSLocalizedString("A chat with this user already exists", comment: "")
            case .noUsername:
                return NSLocalizedString("No username provided", comment: "")
            case .noDevice:
                return NSLocalizedString("No device provided", comment: "")
        }
    }
}
