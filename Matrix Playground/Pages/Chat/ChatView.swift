//
//  ChatView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 07/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import CoreData
import MapKit

struct ChatView: View {
    
    @Environment(\.presentationMode) var presentation
    
    var chatDetails: Chat
    var stopChat: () -> Void
    var stopTransmission: () -> Void
    var startTransmission: () -> Void
    var cancelChangedSessionWarning: () -> Void
    var onTransmissionLongPress: (_: Bool) -> Void
    
    // TODO: Move to controller
    @Binding var centerCoordinate: CLLocationCoordinate2D
    @Binding var locations: [MKPointAnnotation]
    @Binding var isExplanationTextShowing: Bool
    @Binding var showingDeleteAlert: Bool
    @Binding var showingStopTransmissionAlert: Bool
    @Binding var alertItem: AlertItem?
    
    
    /// parseToDate
    /// Takes a time interval and converts it to a user readable date formatted depending on whether it is in the current day or past
    /// - Parameter intervalTo1970: A Double describing the time interval since 1970
    /// - Returns: String containing human readable formatted date
    func parseToDate(intervalTo1970: Double) -> String {
        let date = Date(timeIntervalSince1970: intervalTo1970)
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = DateFormatter.Style.short
        dateFormatter.dateStyle = isToday ? DateFormatter.Style.none : DateFormatter.Style.short
        dateFormatter.timeZone = .current
        return dateFormatter.string(from: date)
    }
    
    /// Structure of the Map portion of the view
    var MapViewStack: some View {
        Group {
            MapView(centerCoordinate: $centerCoordinate, annotations: locations)
                .disabled(!self.chatDetails.receiving)
                .opacity(self.chatDetails.receiving ? 1 : 0.5)
            if !self.chatDetails.receiving {
                Text("No locations received from this user.")
            }
            VStack {
                Spacer()
                if isExplanationTextShowing {
                    ExplanationText(chatDetails: chatDetails).transition(.move(edge: .bottom)).animation(.easeInOut(duration: 0.2))
                }
            }
        }
    }
    
    /// Structure of transmission icons
    var TransmissionIconsStack: some View {
        HStack {
            Image(systemName: "arrow.up").imageScale(.large).foregroundColor(chatDetails.sending ? .green : .red)
            Image(systemName: "arrow.down").imageScale(.large).foregroundColor(chatDetails.receiving ? .green : .red)
            Spacer()
        }.onLongPressGesture(minimumDuration: 3, pressing: { inProgress in
            self.onTransmissionLongPress(inProgress)
        }, perform: {})
    }
    
    /// Structure of Date Text
    var DateTextStack: some View {
        HStack {
            Spacer()
            if (self.chatDetails.receiving) {
                Text(self.parseToDate(intervalTo1970: chatDetails.lastSeen))
            }
            Spacer()
        }
    }
    
    /// Structure of altered session banner
    var AlteredSessionBanner: some View {
        HStack {
            if (self.chatDetails.receiving) {
                Text("Session has been altered")
                    .font(.subheadline)
                Spacer()
                Button(action: cancelChangedSessionWarning, label: {
                    Text("Cancel")
                        .foregroundColor(.black)
                })
                    .padding()
                    .overlay(
                        RoundedRectangle(cornerRadius: 40)
                            .stroke(Color.white, lineWidth: 5)
                    )
            }
        }.padding().background(Color.yellow)
    }
    
    /// Structure of modification buttons
    var ModificationButtonsStack: some View {
        HStack {
            Spacer()
            if (self.chatDetails.sending && self.chatDetails.receiving) {
                Button(action: {
                    self.alertItem = AlertItem(
                        title: Text("Are you sure you want to stop transmission?"),
                        message: Text("This will stop sending your location to \(self.chatDetails.recipientUser ?? "Unknown user")"),
                        primaryButton: .destructive(Text("Stop")) {self.stopTransmission()},
                        secondaryButton: .cancel())
                }) {
                    Image(systemName: "mappin.slash").imageScale(.large).padding(.trailing).foregroundColor(.red)
                }
            }
            if (self.chatDetails.receiving && !self.chatDetails.sending) {
                Button(action: {
                    self.alertItem = AlertItem(
                        title: Text("Start transmitting?"),
                        message: Text("This will begin sending your location to \(self.chatDetails.recipientUser ?? "Unknown user")"),
                        primaryButton: .destructive(Text("Start")) {self.startTransmission()},
                        secondaryButton: .cancel())
                }) {
                    Image(systemName: "mappin").imageScale(.large).padding(.trailing)
                }
            }
            Button(action: {
                self.alertItem = AlertItem(
                    title: Text("Are you sure you want to delete this chat?"),
                    message: Text("This will permanently delete the chat"),
                    primaryButton: .destructive(Text("Delete")) {self.stopChat()},
                    secondaryButton: .cancel())
            }) {
                Image(systemName: "trash").imageScale(.large).foregroundColor(.red)
            }
        }
    }
    
    func createAlert(_ alertItem: AlertItem) -> Alert {
        Alert(
        title: alertItem.title,
        message: alertItem.message,
        primaryButton: alertItem.primaryButton,
        secondaryButton: alertItem.secondaryButton ?? .cancel())
    }
    
    var body: some View {
        VStack {
            ZStack {
                if chatDetails.alteredSession {
                    AlteredSessionBanner.transition(.move(edge: .bottom)).animation(.easeInOut(duration: 0.2))
                }
            }
            ZStack {
                MapViewStack
            }.zIndex(5)
            ZStack {
                TransmissionIconsStack
                DateTextStack
                ModificationButtonsStack
            }.padding(.all).background(Color(UIColor.systemBackground)).zIndex(10)
            Text("").hidden().alert(item: self.$alertItem) { alertItem in
                self.createAlert(alertItem)
            }
        }
        .navigationBarTitle("", displayMode: .inline)
        .navigationBarItems(
            trailing:
                Text(chatDetails.recipientUser ?? "Unknown Username")
        )
    }
}

struct ChatView_Previews: PreviewProvider {
    
    static var previews: some View {
        
        var fakeUser: UserDetails
        
        let context = (UIApplication.shared.delegate as!AppDelegate).persistentContainer.viewContext
        fakeUser = UserDetails.init(context: context)
        fakeUser.userId = "testUser"
        
        // Example receiving only
        let fakeChatOne = Chat.init(context: context)
        fakeChatOne.recipientUser = "testUser2"
        fakeChatOne.sending = false
        fakeChatOne.receiving = true
        fakeChatOne.lastReceivedLatitude = 52.32
        fakeChatOne.lastReceivedLongitude = 3.43
        fakeChatOne.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatOne)
        
        // Example sending only
        let fakeChatTwo = Chat.init(context: context)
        fakeChatTwo.recipientUser = "testUser2"
        fakeChatTwo.sending = true
        fakeChatTwo.receiving = false
        fakeChatTwo.lastReceivedLatitude = 52.32
        fakeChatTwo.lastReceivedLongitude = 3.43
        fakeChatTwo.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatTwo)
        
        // Example both sending and receiving
        let fakeChatThree = Chat.init(context: context)
        fakeChatThree.recipientUser = "testUser2"
        fakeChatThree.sending = true
        fakeChatThree.receiving = true
        fakeChatThree.lastReceivedLatitude = 52.32
        fakeChatThree.lastReceivedLongitude = 3.43
        fakeChatThree.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatThree)
        
        // Example with todays date (short style)
        let fakeChatFour = Chat.init(context: context)
        fakeChatFour.recipientUser = "testUser2"
        fakeChatFour.sending = true
        fakeChatFour.receiving = true
        fakeChatFour.lastReceivedLatitude = 52.32
        fakeChatFour.lastReceivedLongitude = 3.43
        fakeChatFour.lastSeen = Date().timeIntervalSince1970
        fakeUser.addToChats(fakeChatFour)
        
        // Example with altered session
        let fakeChatFive = Chat.init(context: context)
        fakeChatFive.recipientUser = "testUser2"
        fakeChatFive.sending = true
        fakeChatFive.receiving = true
        fakeChatFive.lastReceivedLatitude = 52.32
        fakeChatFive.lastReceivedLongitude = 3.43
        fakeChatFive.lastSeen = Date().timeIntervalSince1970
        fakeChatFive.alteredSession = true
        fakeUser.addToChats(fakeChatFive)
        
        return Group {
            PreviewWrapper(chatDetails: fakeUser.chats!.array[0] as! Chat).previewDisplayName("Receiving Only")
            PreviewWrapper(chatDetails: fakeUser.chats!.array[1] as! Chat).previewDisplayName("Sending Only")
            PreviewWrapper(chatDetails: fakeUser.chats!.array[2] as! Chat).previewDisplayName("Sending and Receiving")
            PreviewWrapper(chatDetails: fakeUser.chats!.array[3] as! Chat).previewDisplayName("Previous date")
            PreviewWrapper(chatDetails: fakeUser.chats!.array[4] as! Chat).previewDisplayName("Altered Session")
        }
    }
    
    struct PreviewWrapper: View {
        var chatDetails: Chat
        
        @State(initialValue: CLLocationCoordinate2D.init(latitude: -1.1, longitude: 52.3)) var centerCoordinate: CLLocationCoordinate2D
        @State(initialValue: []) var locations: [MKPointAnnotation]
        @State(initialValue: false) var isExplanationTextShowing: Bool
        @State(initialValue: false) var showingDeleteAlert: Bool
        @State(initialValue: false) var showingStopTransmissionAlert: Bool
        @State(initialValue: nil) var alertItem: AlertItem?
        
        func stopChat () {return}
        func stopTransmission () {return}
        func startTransmission () {return}
        func cancelChangedSessionWarning () {return}
        func onTransmissionLongPress (inProgress: Bool) {self.isExplanationTextShowing = inProgress}

        var body: some View {
            
            let annotation = MKPointAnnotation()
            annotation.coordinate = centerCoordinate
            locations.append(annotation)
            
            return ChatView(
                chatDetails: chatDetails,
                stopChat: stopChat,
                stopTransmission: stopTransmission,
                startTransmission: startTransmission,
                cancelChangedSessionWarning: cancelChangedSessionWarning,
                onTransmissionLongPress: onTransmissionLongPress,
                centerCoordinate: $centerCoordinate,
                locations: $locations,
                isExplanationTextShowing: $isExplanationTextShowing,
                showingDeleteAlert: $showingDeleteAlert,
                showingStopTransmissionAlert: $showingStopTransmissionAlert,
                alertItem: $alertItem
            )
        }
    }
    
}
