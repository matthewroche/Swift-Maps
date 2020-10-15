//
//  EncryptionError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 31/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum EncryptionError: LocalizedError {
    case noCredentialsAvailable
    case existingAccount
    case noAccount
    case existingSession
    case noSession
    case inboundSessionDoesntMatch
    case noMatchingIdentityKey
    case deviceDoesNotExist
    case noPreKeysAvailable
    case prekeyFailedVerification
    case noSignature
    case invalidCombinedName
    case storedSessionsAndRecipientDevicesDoNotMatch
    case keyUploadFailed
}

extension EncryptionError {
    public var errorDescription: String? {
        switch self {
            case .noCredentialsAvailable:
                return NSLocalizedString("There are no credentials available locally to enable encryption", comment: "")
            case .existingAccount:
                return NSLocalizedString("An encryption account already exists locally", comment: "")
            case .noAccount:
                return NSLocalizedString("There is no encryption account available", comment: "")
            case .existingSession:
                return NSLocalizedString("An encryption session already exists", comment: "")
            case .noSession:
                return NSLocalizedString("There is no encryption session available", comment: "")
            case .inboundSessionDoesntMatch:
                return NSLocalizedString("The encryption session identified locally does not match the session in the message", comment: "")
            case .noMatchingIdentityKey:
                return NSLocalizedString("The identity key saved locally does not match that received in the message", comment: "")
            case .deviceDoesNotExist:
                return NSLocalizedString("The requested recipient device does not exist", comment: "")
            case .noPreKeysAvailable:
                return NSLocalizedString("The recipient device has no prekeys available", comment: "")
            case .prekeyFailedVerification:
                return NSLocalizedString("The prekey received from the server failed verification", comment: "")
            case .noSignature:
                return NSLocalizedString("The prekey received from the server does not contain any signatures", comment: "")
            case .invalidCombinedName:
                return NSLocalizedString("The combined name provided was invalid", comment: "")
            case .storedSessionsAndRecipientDevicesDoNotMatch:
                return NSLocalizedString("There was an issue with the sotred data", comment: "")
            case .keyUploadFailed:
                return NSLocalizedString("An invalid response was returned from the server when uploading the encryption keys", comment: "")
        }
    }
}
