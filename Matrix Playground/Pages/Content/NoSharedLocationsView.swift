//
//  NoSharedLocationsView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI

struct NoSharedLocationsView: View {
    
    @Binding var newChatModalVisible: Bool
    
    var body: some View {
        VStack {
            Text("No shared locations yet!")
            Button(action: {self.newChatModalVisible = true}) {
                HStack {
                    Image(systemName: "person.badge.plus").padding(.trailing)
                    Text("Start a new chat")
                }
            }
            .buttonStyle(RoundedButtonStyle(backgroundColor: Color("Primary")))
        }.padding(.top)
    }
}
