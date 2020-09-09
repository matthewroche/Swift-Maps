//
//  AlertWithTextbox.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 01/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftUI
import Then

public struct LogoutAndDeleteDataModal: View {
    
    var logoutAndDeleteData: (String) -> Promise<Void>
    @State var password: String = ""
    @State var noPasswordAlertVisible = false
    @State var processingLogout = false
    
    @Environment(\.presentationMode) var presentationMode
    
    func handleSubmit () -> Void {
        async {
            if self.password.count > 0 {
                self.processingLogout = true
                try await(self.logoutAndDeleteData(self.password))
                self.processingLogout = false
            } else {
                self.noPasswordAlertVisible = true
            }
        }

    }
    
    public var body: some View {
        VStack(alignment: .leading) {
            Text("Log Out And Delete Data")
                .font(.title)
            Spacer()
            GeometryReader { geo in
                HStack {
                    Spacer()
                    Image(systemName: "trash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width/3)
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .foregroundColor(Color("Primary"))
                    Spacer()
                }
            }
            Spacer()
            Group {
                Text("Performing this action will delete all data stored on this device for this user.").padding(.bottom)
                Text("Additionally, the device will be deleted from the server.").padding(.bottom)
                Text("It will not be possible to recover this data.").padding(.bottom)
            }
            Spacer()
            SecureField(
                "Password",
                text: $password,
                onCommit: handleSubmit)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .padding(.bottom)
            Button(action: handleSubmit) {
                HStack {
                    if self.processingLogout {
                        ActivityIndicator(isAnimating: true)
                    }
                    Text("Submit")
                }
            }
                .disabled(self.processingLogout)
                .buttonStyle(RoundedButtonStyle(backgroundColor: Color.red))
            Spacer()
            Group {
                Button("Cancel", action: {self.presentationMode.wrappedValue.dismiss()}).frame(maxWidth: .infinity)
                Text("").hidden().alert(isPresented: $noPasswordAlertVisible) {
                    Alert(title: Text("You must provide a password to perform this action."))
                }
            }
        }
        .padding()
        .modifier(AdaptsToKeyboard())
    }
}

struct LogoutAndDeleteDataModal_Previews: PreviewProvider {
    
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
    
        func logoutAndDeleteData(password: String) -> Promise<Void> {
            return Promise() { resolve, reject in
                resolve()
            }
        }

        var body: some View {
            
            return LogoutAndDeleteDataModal(
                logoutAndDeleteData: logoutAndDeleteData)
        }
    }
    
}
