//
//  ContentError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 22/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum ContentError: LocalizedError {
    case noUsername
    case noDevice
    case invalidLocationReceived
    case duplicateChat
    case notLoggedIn
    case unableToSendMessage
    case passwordDoesNotExist
    case unableToDeleteUser
}

extension ContentError {
    public var errorDescription: String? {
        switch self {
            case .noUsername:
                return NSLocalizedString("No username was provided", comment: "")
            case .noDevice:
                return NSLocalizedString("No device was provided", comment: "")
            case .invalidLocationReceived:
                return NSLocalizedString("The data received from the server was incorrectly formatted", comment: "")
            case .duplicateChat:
                return NSLocalizedString("A chat already exists with this device", comment: "")
            case .notLoggedIn:
                return NSLocalizedString("You are not logged in", comment: "")
            case .unableToSendMessage:
                return NSLocalizedString("Unable to send message.", comment: "")
            case .passwordDoesNotExist:
                return NSLocalizedString("No password was provided.", comment: "")
        case .unableToDeleteUser:
            return NSLocalizedString("Unable to delete user", comment: "")
        }
    }
}
