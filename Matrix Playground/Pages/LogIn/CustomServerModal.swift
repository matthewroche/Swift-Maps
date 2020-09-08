//
//  CustomServerModal.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 30/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

//
//  NewChatModal.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 09/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI

struct CustomServerModal: View {
    
    @Binding var serverAddress: String
    @State var showInvalidServerText = false
    
    @Environment(\.presentationMode) var presentationMode
    
    private func handleSetServer() -> Void {
        self.presentationMode.wrappedValue.dismiss()
    }
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Use a custom server")
                .font(.title)
            Spacer()
            TextFieldWithTitleAndValidation(
                title: "Server Address",
                invalidText: "Server address is invalid",
                validRegex: "^https?:\\/\\/(www\\.)?[a-z0-9]*?\\.?[a-z0-9]*\\.[a-z]{2,3}(\\.[a-z]{2,3})?$",
                text: $serverAddress,
                showInvalidText: $showInvalidServerText,
                onCommit: handleSetServer
            )
            .padding(.bottom)
            Button("Set", action: handleSetServer)
                .disabled(showInvalidServerText)
                .buttonStyle(RoundedButtonStyle(backgroundColor: Color("Primary")))
            Spacer()
        }
        .padding()
    }
}

struct CustomServerModal_Previews: PreviewProvider {
    
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        
        @State(initialValue: "") var serverAddress: String

        var body: some View {
            
            return CustomServerModal(
                serverAddress: $serverAddress)
        }
    }
    
}
