//
//  LoginError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 12/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum LoginError: LocalizedError {
    case noUsername
    case noPassword
    case invalidUsername
    case invalidPassword
    case saveUserFailed
    case invalidServerResponse
    case unableToSetUpEncryption
    case invalidServerAddress
}

extension LoginError {
    public var errorDescription: String? {
        switch self {
            case .noUsername:
                return NSLocalizedString("No username was provided", comment: "")
            case .noPassword:
                return NSLocalizedString("No password was provided", comment: "")
            case .invalidUsername:
                return NSLocalizedString("The provided username is invalid", comment: "")
            case .invalidPassword:
                return NSLocalizedString("The provided password is invalid", comment: "")
            case .saveUserFailed:
                return NSLocalizedString("Unable to save the user's details", comment: "")
            case .invalidServerResponse:
                return NSLocalizedString("The response received from the server was invalid", comment: "")
            case .unableToSetUpEncryption:
                return NSLocalizedString("Unable to set up encryption locally", comment: "")
            case .invalidServerAddress:
                return NSLocalizedString("The server address provided is invalid", comment: "")
        }
    }
}
