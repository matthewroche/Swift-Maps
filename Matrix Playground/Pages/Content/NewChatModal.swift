//
//  NewChatModal.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 09/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI

struct NewChatModal: View {
    var startChat: () -> Void
    
    @Binding var inviteUser: String
    @Binding var inviteDevice: String
    @Binding var startChatInProgress: Bool
    @State var invalidUserName: Bool = true
    @State var invalidDeviceName: Bool = true
    
    
    @Environment(\.presentationMode) var presentationMode
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Start a new chat")
                .font(.title)
            GeometryReader { geo in
                HStack {
                    Spacer()
                    Image(systemName: "person.badge.plus")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: geo.size.width/3)
                        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
                        .foregroundColor(Color("Primary"))
                    Spacer()
                }
            }
            Spacer()
            TextFieldWithTitleAndValidation(
                title: "User Name",
                invalidText: "User name is invalid",
                validRegex: "^@[a-z0-9]*:[a-z0-9]*?\\.?[a-z0-9]*\\.[a-z]{2,3}(\\.[a-z]{2,3})?$",
                text: $inviteUser,
                showInvalidText: $invalidUserName
            )
            .padding(.bottom)
            TextFieldWithTitleAndValidation(
                title: "Device Name",
                invalidText: "Device name is invalid",
                validRegex: "^[A-Z]{10}$",
                text: $inviteDevice,
                showInvalidText: $invalidDeviceName,
                onCommit: startChat
            )
            .padding(.bottom)
            Button(action: startChat) {
                HStack {
                    if (self.startChatInProgress) {
                        ActivityIndicator(isAnimating: true)
                    }
                    Text("Start Chat")
                }
            }
            .disabled(invalidDeviceName || invalidUserName || startChatInProgress)
            .buttonStyle(RoundedButtonStyle(backgroundColor: Color("Primary")))
            Spacer()
            Button(action: {self.presentationMode.wrappedValue.dismiss()}) {
                Spacer()
                Text("Cancel")
                Spacer()
            }
        }
        .padding()
        .modifier(AdaptsToKeyboard())
    }
    
}

struct NewChatModal_Previews: PreviewProvider {
    
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        @State(initialValue: "") var inviteUser: String
        @State(initialValue: "") var inviteDevice: String
        @State(initialValue: false) var startChatInProgress: Bool
        
        func startChat () {}

        var body: some View {
            
            return NewChatModal(
                startChat: startChat,
                inviteUser: $inviteUser,
                inviteDevice: $inviteDevice,
                startChatInProgress: $startChatInProgress)
        }
    }
    
}
