//
//  LogInView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 07/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import Then

struct LogInView: View {
    
    var performLogin: () -> Promise<Void>
    
    @Binding var username: String
    @Binding var password: String
    @Binding var serverAddress: String
    @Binding var customServerModalVisible: Bool
    @State var invalidUsername = false
    @State var invalidPassword = false
    @State var loginInProgress = false
    
    // This is required to allow modal to be displayed multiple times
    // See: https://stackoverflow.com/questions/58512344/swiftui-navigation-bar-button-not-clickable-after-sheet-has-been-presented
    @Environment(\.presentationMode) var presentation
    
    var loginParsedServerAddress: String {
        return serverAddress.components(separatedBy: "://").last ?? "** Unknown Address **"
    }
    
    func handleLogin() -> Void {
        async {
            self.loginInProgress = true
            try await(self.performLogin())
            self.loginInProgress = false
        }
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            GeometryReader { geo in
                HStack {
                    Spacer()
                    Image("Icon")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width/2)
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                    Spacer()
                }
            }
            TextFieldWithTitleAndValidation(
                title: "Username",
                invalidText: "Invalid username",
                validRegex: "[a-zA-Z0-9]*",
                text: $username,
                showInvalidText: $invalidUsername
            )
            TextFieldWithTitleAndValidation(
                title: "Password",
                invalidText: "Invalid password",
                secureField: true,
                text: $password,
                showInvalidText: $invalidPassword,
                onCommit: self.handleLogin
            )
            Spacer()
            if self.username.count > 0 {
                Group {
                    Text("Logging in as:").foregroundColor(Color(.gray))
                    Text("@\(self.username):\(self.loginParsedServerAddress)").foregroundColor(Color(.gray))
                }
                .transition(.move(edge: .leading))
                .animation(.easeInOut(duration: 0.2))
            }
            Button(action: self.handleLogin) {
                HStack {
                    if (self.loginInProgress) {
                        ActivityIndicator(isAnimating: true)
                    }
                    Text("Login")
                }
            }
            .disabled(invalidUsername || invalidPassword || loginInProgress)
            .buttonStyle(RoundedButtonStyle(backgroundColor: Color("Primary")))
            Text("").hidden().sheet(
            isPresented: $customServerModalVisible) {
                CustomServerModal(serverAddress: self.$serverAddress)
            }
        }
        .padding()
        .navigationBarTitle("Log In")
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Text(""),
            trailing: Button(action: {self.customServerModalVisible.toggle()}) {
                Image(systemName: "gear").imageScale(.large).foregroundColor(Color("Primary"))
        })
    }
}

struct LogInView_Previews: PreviewProvider {
    
    static var previews: some View {
        Group {
            PreviewWrapper()
            PreviewWrapper().darkModeFix()
        }
        
    }
    
    struct PreviewWrapper: View {
        @State(initialValue: "matrixMapsTest") var username: String
        @State(initialValue: "") var password: String
        @State(initialValue: "matrix.org") var serverAddress: String
        @State(initialValue: false) var customServerModalVisible: Bool
        
        func login () -> Promise<Void> {
            return Promise() {resolve, reject in
                resolve()
            }
        }
        func setCustomServer () {return}

          var body: some View {
            LogInView(
                performLogin: login,
                username: $username,
                password: $password,
                serverAddress: $serverAddress,
                customServerModalVisible: $customServerModalVisible
            )
          }
    }
}
