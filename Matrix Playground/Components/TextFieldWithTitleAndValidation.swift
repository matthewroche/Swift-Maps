//
//  TextFieldWithTitleAndValidation.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 29/08/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftUI

struct TextFieldWithTitleAndValidation: View {
    
    var title: String
    var invalidText: String
    var validRegex: String = ".*"
    var secureField: Bool = false
    @Binding var text: String
    @Binding var showInvalidText: Bool
    
    /// validateText
    /// Validates text in the TextField depending on whether the field is still being edited
    /// Text is assumed to be valid until editing has finished
    /// - Parameter editing: Whether editing is still in progress
    /// - Returns: A Bool defining whther text is valid
    private func validateText(editing: Bool) -> Void {
        if (!editing) {
            let predicate = NSPredicate(format:"SELF MATCHES %@", validRegex)
            showInvalidText = !predicate.evaluate(with: text)
        } else {
            showInvalidText = false
        }
    }
    
    var body: some View {
        VStack {
            VStack {
                Text(title)
                if !secureField {
                    TextField(
                        title,
                        text: $text,
                        onEditingChanged: validateText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                } else {
                    SecureField(
                        title,
                        text: $text)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                }
                
            }
            ZStack {
                // A blank Text is retained when no error is show to prevent vertical movement on insertion
                // of the error text
                Text("").frame(maxWidth: .infinity).padding(.top, 10)
                if (showInvalidText && text.count > 0) {
                    Text(invalidText)
                        .frame(maxWidth: .infinity)
                        .background(Color.orange)
                        .transition(.move(edge: .leading))
                        .animation(.easeInOut(duration: 0.2))
                }
            }
        }
    }
    
}

struct TextFieldWithTitleAndValidation_Previews: PreviewProvider {
    
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        var title: String = "Username"
        var invalidText: String = "This is invalid"
        var validRegex: String = "^[A-Za-z0-9]*$"
        @State var text: String = ""
        @State var showInvalidText: Bool = false
        
        func startChat () {return}

        var body: some View {
            
            return TextFieldWithTitleAndValidation(
                title: title,
                invalidText: invalidText,
                validRegex: validRegex,
                text: $text,
                showInvalidText: $showInvalidText
            )
        }
    }
    
}
