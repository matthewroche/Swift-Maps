//
//  ChatRow.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 11/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI

struct ChatRow: View {
    
    var chatItem: Chat
    
    @Binding var refreshing: Bool
    
    /// parseToDate
    ///  Parses a date to a human readable string, the format of which depends on the precise date provided
    /// - Parameter intervalTo1970: A Double defining number of ms from 1970
    /// - Returns: A formatted String
    func parseToDate(intervalTo1970: Double) -> String {
        let date = Date(timeIntervalSince1970: intervalTo1970)
        let calendar = Calendar.current
        let isToday = calendar.isDateInToday(date)
        let dateFormatter = DateFormatter()
        dateFormatter.timeStyle = isToday ? DateFormatter.Style.short : DateFormatter.Style.none
        dateFormatter.dateStyle = isToday ? DateFormatter.Style.none : DateFormatter.Style.short
        dateFormatter.timeZone = .current
        return dateFormatter.string(from: date)
    }
    
    var body: some View {
        NavigationLink(destination: ChatController(chatDetails: chatItem)) {
            VStack(alignment: .leading) {
                Text(chatItem.recipientUser ?? "Unknown User").font(.headline)
                HStack() {
                    Text(chatItem.recipientDevice ?? "Unknown Device")
                    Spacer()
                    Text(parseToDate(intervalTo1970: chatItem.lastSeen) + (self.refreshing ? "" : ""))
                    Spacer()
                    HStack {
                        Image(systemName: "arrow.up").imageScale(.large).foregroundColor(chatItem.sending ? .green : .red)
                        Image(systemName: "arrow.down").imageScale(.large).foregroundColor(chatItem.receiving ? .green : .red)
                    }
                }
                
            }.padding()
        }
    }
}

struct ChatRow_Previews: PreviewProvider {
    
    static var previews: some View {
        
        var fakeUser: UserDetails

        let context = (UIApplication.shared.delegate as!AppDelegate).persistentContainer.viewContext
        fakeUser = UserDetails.init(context: context)
        fakeUser.userId = "testUser"

        // Example receiving only
        let fakeChatOne = Chat.init(context: context)
        fakeChatOne.recipientUser = "@testUser1:matrix.org"
        fakeChatOne.recipientDevice = "ASHFYDTGD"
        fakeChatOne.sending = false
        fakeChatOne.receiving = true
        fakeChatOne.lastReceivedLatitude = 52.32
        fakeChatOne.lastReceivedLongitude = 3.43
        fakeChatOne.lastSeen = 1576934977
        fakeUser.addToChats(fakeChatOne)

        // Example sending only
        let fakeChatTwo = Chat.init(context: context)
        fakeChatTwo.recipientUser = "@testUser2:matrix.org"
        fakeChatTwo.recipientDevice = "ASHFYDTGD"
        fakeChatTwo.sending = true
        fakeChatTwo.receiving = false
        fakeChatTwo.lastReceivedLatitude = 52.32
        fakeChatTwo.lastReceivedLongitude = 3.43
        fakeChatTwo.lastSeen = Date().timeIntervalSince1970
        fakeUser.addToChats(fakeChatTwo)

        // Example both sending and receiving
        let fakeChatThree = Chat.init(context: context)
        fakeChatThree.recipientUser = "@testUser3:matrix.org"
        fakeChatThree.recipientDevice = "ASHFYDTGD"
        fakeChatThree.sending = true
        fakeChatThree.receiving = true
        fakeChatThree.lastReceivedLatitude = 52.32
        fakeChatThree.lastReceivedLongitude = 3.43
        fakeChatThree.lastSeen = Date().timeIntervalSince1970 - 10000
        fakeUser.addToChats(fakeChatThree)
        
        return Group {
            PreviewWrapper(chatItem: fakeUser.chats!.array[0] as! Chat)
                .previewDisplayName("Receiving Only")
                .previewLayout(.fixed(width: 350, height: 120))
            PreviewWrapper(chatItem: fakeUser.chats!.array[0] as! Chat)
                .darkModeFix()
                .previewDisplayName("Receiving Only (Dark Mode)")
                .previewLayout(.fixed(width: 350, height: 120))
            PreviewWrapper(chatItem: fakeUser.chats!.array[1] as! Chat)
                .previewDisplayName("Sending Only")
                .previewLayout(.fixed(width: 350, height: 120))
            PreviewWrapper(chatItem: fakeUser.chats!.array[2] as! Chat)
                .previewDisplayName("Both sending and receiving")
                .previewLayout(.fixed(width: 350, height: 120))
        }
    }
    
    struct PreviewWrapper: View {
        
        var chatItem: Chat
        
        @State(initialValue: false) var refreshing: Bool

        var body: some View {
            return ChatRow(chatItem: chatItem, refreshing: $refreshing)
        }
    }
    
}
