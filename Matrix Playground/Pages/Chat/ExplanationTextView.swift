//
//  ExplanationTextView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 31/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftUI

struct ExplanationText: View {
    
    var chatDetails: Chat
    
    var body: some View {
        if (self.chatDetails.sending && self.chatDetails.receiving) {
            return HStack {
                Text("You are sending and receiving data").padding()
                Spacer()
            }.background(Color.white)
        }
        if (self.chatDetails.sending && !self.chatDetails.receiving) {
            return HStack {
                Text("You are only sending data").padding()
                Spacer()
            }.background(Color.white)
        }
        if (!self.chatDetails.sending && self.chatDetails.receiving) {
            return HStack {
                Text("You are only receiving data").padding()
                Spacer()
            }.background(Color.white)
        }
        return HStack {
            Text("You are not sending or receiving data").padding()
            Spacer()
        }.background(Color.white)
    }
}
