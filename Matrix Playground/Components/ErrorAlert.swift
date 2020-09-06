//
//  ErrorAlert.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI

public func ErrorAlert(viewError: IdentifiableError) -> Alert {
    return Alert(
        title: Text("Error"),
        message: Text(viewError.error.localizedDescription),
        dismissButton: .cancel()
    )
}
