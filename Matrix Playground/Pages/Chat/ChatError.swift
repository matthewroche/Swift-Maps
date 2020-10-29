//
//  LoginError.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 08/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

enum ChatError: LocalizedError {
    case notLoggedIn
    case newSenderMessageErrors([EncryptedMessageRecipient])
    
}

extension ChatError {
    public var errorDescription: String? {
        switch self {
            case .notLoggedIn:
                return NSLocalizedString("User is not logged in", comment: "")
            case .newSenderMessageErrors(let errorSenders):
                var senderStrings = ""
                for sender in errorSenders {
                    senderStrings.append("\(sender.combinedName), ")
                }
                senderStrings = String(senderStrings.dropLast(2))
                return NSLocalizedString("Errors for users: \(senderStrings)", comment: "")
        }
    }
}
