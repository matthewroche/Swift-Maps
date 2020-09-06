//
//  SwiftUIView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 09/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import CoreData
import Then

struct LogInController: View {
    
    var loginLogic = LoginLogic()
    
    @State private var username = ""
    @State private var password = ""
    @State private(set) var viewError: IdentifiableError?
    @State private var isLoggingIn = false
    @State private var serverAddress = "https://matrix.org"
    @State private var customServerModalVisible = false
    
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject var sessionData: SessionData
    
    
    /// Login
    /// Logs the user into the server and displays any errors resulting from this
    /// - Returns: Promise
    private func login() -> Promise<Void> {
        async {
            let _ = try await(
                self.loginLogic.login(
                    username: self.username,
                    password: self.password,
                    context: self.context,
                    sessionData: self.sessionData,
                    serverAddress: self.serverAddress
            ))
        }.onError { error in
            print("error executing login request: \(error)")
            self.viewError = IdentifiableError(error)
            self.isLoggingIn = false
        }
    }
    
    var body: some View {
        
        ZStack {
            LogInView(
                performLogin: login,
                username: $username,
                password: $password,
                serverAddress: $serverAddress,
                customServerModalVisible: $customServerModalVisible
                )
            Text("").hidden().alert(item: self.$viewError) { viewError -> Alert in
                return ErrorAlert(viewError: viewError)
            }
        }
        
    }
}

