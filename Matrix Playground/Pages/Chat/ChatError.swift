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
}

extension ChatError {
    public var errorDescription: String? {
        switch self {
            case .notLoggedIn:
                return NSLocalizedString("User is not logged in", comment: "")
        }
    }
}
