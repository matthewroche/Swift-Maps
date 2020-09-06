//
//  ContentView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import CoreData
import Then

struct ContentView: View {
    
    var chatArray: Array<Chat>
    
    var sync: () -> Void
    
    var userName: String
    @Binding var deviceName: String
    @Binding var newChatModalVisible: Bool
    @Binding var refreshing: Bool
    @Binding var showingLogOutActionSheet: Bool
    @Binding var syncInProgress: Bool
    
    @State var isSyncAnimating = false
    
    // This is required to allow modal to be displayed multiple times
    // See: https://stackoverflow.com/questions/58512344/swiftui-navigation-bar-button-not-clickable-after-sheet-has-been-presented
    @Environment(\.presentationMode) var presentation
    
    // Defines animation for the sync icon
    var foreverAnimation: Animation {
        Animation.linear(duration: 2.0)
            .repeatForever(autoreverses: false)
    }
    
    // Defines the rotating sync icon
    var AnimatingSyncButton: some View {
        Image(systemName: "arrow.clockwise.circle")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .imageScale(.large)
            .frame(minWidth: 22, minHeight: 22)
            .rotationEffect(Angle(degrees: self.isSyncAnimating ? 360.0 : 0.0))
            .animation(self.isSyncAnimating ? foreverAnimation : .none)
            .onAppear { self.isSyncAnimating = true }
            .onDisappear { self.isSyncAnimating = false }
    }
    
    // Defines the static sync button
    var StaticSyncButton: some View {
        Image(systemName: "arrow.clockwise.circle")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .imageScale(.large)
    }
    
    // Defines the new chat icon
    var NewChatIcon: some View {
        Image(systemName: "person.badge.plus")
        .resizable()
        .aspectRatio(contentMode: .fill)
        .imageScale(.large)
        .frame(minWidth: 22, minHeight: 22)
    }
    
    var body: some View {
        VStack {
            if (chatArray.count > 0) {
                List(chatArray, id: \.self) { chat in
                    ChatRow(chatItem: chat, refreshing: self.$refreshing)
                }
            } else {
                NoSharedLocationsView(newChatModalVisible: $newChatModalVisible)
            }
            Spacer()
            Text("User name: \(userName)")
            Text("Device name: \(deviceName)").padding(.bottom)
        }
        .navigationBarTitle("Matrix Maps")
        .navigationBarBackButtonHidden(true)
        .navigationBarItems(
            leading: Button(action: {self.showingLogOutActionSheet = true}) { Text("Log Out") },
            trailing:
            HStack(alignment: .center) {
                Button(action: {self.sync()}) {
                    if self.syncInProgress {
                        AnimatingSyncButton
                    } else {
                        StaticSyncButton
                    }
                }.frame(minWidth: 22, minHeight: 22).padding(.trailing)
                Button(action: {self.newChatModalVisible = true}) {
                    NewChatIcon
                }.frame(minWidth: 22, minHeight: 22)
            }
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    
    static var previews: some View {
        var fakeUser: UserDetails

        let context = (UIApplication.shared.delegate as!AppDelegate).persistentContainer.viewContext
        fakeUser = UserDetails.init(context: context)
        fakeUser.userId = "testUser"

        // Example receiving only
        let fakeChatOne = Chat.init(context: context)
        fakeChatOne.recipientUser = "testUser1"
        fakeChatOne.recipientDevice = "FGSHDYRGR"
        fakeChatOne.sending = false
        fakeChatOne.receiving = true
        fakeChatOne.lastReceivedLatitude = 52.32
        fakeChatOne.lastReceivedLongitude = 3.43
        fakeChatOne.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatOne)

        // Example sending only
        let fakeChatTwo = Chat.init(context: context)
        fakeChatTwo.recipientUser = "testUser2"
        fakeChatTwo.recipientDevice = "FGSHDYRGR"
        fakeChatTwo.sending = true
        fakeChatTwo.receiving = false
        fakeChatTwo.lastReceivedLatitude = 52.32
        fakeChatTwo.lastReceivedLongitude = 3.43
        fakeChatTwo.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatTwo)

        // Example both sending and receiving
        let fakeChatThree = Chat.init(context: context)
        fakeChatThree.recipientUser = "testUser3"
        fakeChatThree.recipientDevice = "FGSHDYRGR"
        fakeChatThree.sending = true
        fakeChatThree.receiving = true
        fakeChatThree.lastReceivedLatitude = 52.32
        fakeChatThree.lastReceivedLongitude = 3.43
        fakeChatThree.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatThree)

        // Example with todays date (short style)
        let fakeChatFour = Chat.init(context: context)
        fakeChatFour.recipientUser = "testUser4"
        fakeChatFour.recipientDevice = "FGSHDYRGR"
        fakeChatFour.sending = true
        fakeChatFour.receiving = true
        fakeChatFour.lastReceivedLatitude = 52.32
        fakeChatFour.lastReceivedLongitude = 3.43
        fakeChatFour.lastSeen = Date().timeIntervalSince1970
        fakeUser.addToChats(fakeChatFour)
        
        // Additional chat
        let fakeChatFive = Chat.init(context: context)
        fakeChatFive.recipientUser = "testUser4"
        fakeChatFive.recipientDevice = "FGSHDYRGR"
        fakeChatFive.sending = true
        fakeChatFive.receiving = true
        fakeChatFive.lastReceivedLatitude = 52.32
        fakeChatFive.lastReceivedLongitude = 3.43
        fakeChatFive.lastSeen = Date().timeIntervalSince1970 - 10000
        fakeUser.addToChats(fakeChatFive)
        
        // Additional chat
        let fakeChatSix = Chat.init(context: context)
        fakeChatSix.recipientUser = "testUser4"
        fakeChatSix.recipientDevice = "FGSHDYRGR"
        fakeChatSix.sending = true
        fakeChatSix.receiving = true
        fakeChatSix.lastReceivedLatitude = 52.32
        fakeChatSix.lastReceivedLongitude = 3.43
        fakeChatSix.lastSeen = Date().timeIntervalSince1970 - 10000 * 2
        fakeUser.addToChats(fakeChatSix)
        
        // Additional chat
        let fakeChatSeven = Chat.init(context: context)
        fakeChatSeven.recipientUser = "testUser4"
        fakeChatSeven.recipientDevice = "FGSHDYRGR"
        fakeChatSeven.sending = true
        fakeChatSeven.receiving = true
        fakeChatSeven.lastReceivedLatitude = 52.32
        fakeChatSeven.lastReceivedLongitude = 3.43
        fakeChatSeven.lastSeen = Date().timeIntervalSince1970 - 10000 * 3
        fakeUser.addToChats(fakeChatSeven)
        
        // Additional chat
        let fakeChatEight = Chat.init(context: context)
        fakeChatEight.recipientUser = "testUser4"
        fakeChatEight.recipientDevice = "FGSHDYRGR"
        fakeChatEight.sending = true
        fakeChatEight.receiving = true
        fakeChatEight.lastReceivedLatitude = 52.32
        fakeChatEight.lastReceivedLongitude = 3.43
        fakeChatEight.lastSeen = Date().timeIntervalSince1970 - 10000 * 4
        fakeUser.addToChats(fakeChatEight)

        return Group {
            PreviewWrapper(chatArray: fakeUser.chats!.array as! [Chat]).previewDisplayName("Full Set")
            PreviewWrapper(chatArray: Array(fakeUser.chats!.array.prefix(3)) as! [Chat]).previewDisplayName("Partial Set")
            PreviewWrapper(chatArray: [] as! [Chat]).previewDisplayName("Empty")
        }
    }
    
    struct PreviewWrapper: View {
        
        var chatArray: [Chat]
        
        var userName: String = "testuser"
        @State(initialValue: "DHFGYRYDHD") var deviceName: String
        @State(initialValue: "") var inviteUser: String
        @State(initialValue: "") var inviteDevice: String
        @State(initialValue: false) var newChatModalVisible: Bool
        @State(initialValue: false) var refreshing: Bool
        @State(initialValue: false) var showingLogOutActionSheet: Bool
        @State(initialValue: false) var syncInProgress: Bool
        
        func startChat () {newChatModalVisible.toggle()}
        func sync () {return}

        var body: some View {
            
            return ContentView(
                chatArray: chatArray,
                sync: sync,
                userName: userName,
                deviceName: $deviceName,
                newChatModalVisible: $newChatModalVisible,
                refreshing: $refreshing,
                showingLogOutActionSheet: $showingLogOutActionSheet,
                syncInProgress: $syncInProgress
            )//.environment(\.managedObjectContext, context)
        }
    }
    
}
