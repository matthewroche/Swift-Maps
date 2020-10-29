//
//  RootView.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 07/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import MatrixSDK
import CoreLocation
import Then
import CoreData

struct RootView: View {
    
    @State private(set) var viewError: IdentifiableError?
    
    @Environment(\.managedObjectContext) var context
    @EnvironmentObject var sessionData: SessionData
    
    @ObservedObject var rootState = RootState()
    
    let messagingLogic = MessagingLogic()
    
    
    /// newRestClientReceived
    /// Modifies logged in state depending on whether credentials exist in MXRestClient
    /// - Parameter newRestClient: The new MXRestCient to act on
    /// - Returns: Void
    func newRestClientReceived(_ newRestClient: MXRestClient?) -> Void {
        if newRestClient?.credentials?.userId != nil {
            rootState.state = .loggedIn
        } else if rootState.state != .loggedOut {
            rootState.state = .loggedOut
        }
    }
    
    /// newLocationReceived
    /// Handles a new location being observed from LocationLogic
    /// - Parameter newLocation: The new location to act on
    /// - Returns: Void
    func newLocationReceived(_ newLocation: CLLocation?, repeatAttempt: Bool = false) -> Promise<Bool> {
        return Promise { resolve, reject in
            async {
                print("Ready to update location")
                guard newLocation != nil else {resolve(false); return}
                guard self.sessionData.mxRestClient.credentials?.userId != nil else {resolve(false); return}
                
                let outcomeForRecipients = try await(self.messagingLogic.updateAllRecipientsWithNewLocation(
                    location: newLocation!,
                    encryptionHandler: self.sessionData.encryptionHandler,
                    context: self.context
                ))
                
                if (outcomeForRecipients.failure.count != 0) {
                    //Remove first failed chat then try again
                    let failedMessage = outcomeForRecipients.failure[0]
                    try await(self.handleFailedMessage(failedMessage: failedMessage))
                }
                resolve(true)
            }
        }
    }
    
    private func handleFailedMessage(failedMessage: (EncryptedMessageRecipient, Error)) -> Promise<Bool> {
        async {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
            let recipientUserPredicate = NSPredicate(format: "recipientUser == %@", failedMessage.0.userName)
            let recipientDevicePredicate = NSPredicate(format: "recipientDevice == %@", failedMessage.0.deviceName)
            let ownerPredicate = NSPredicate(
                format: "ownerUser.userId == %@",
                self.sessionData.mxRestClient.credentials?.userId ?? "")
            fetchRequest.predicate = NSCompoundPredicate(
                type: .and,
                subpredicates: [recipientUserPredicate, recipientDevicePredicate, ownerPredicate])
            let chatToRemove = (try self.context.fetch(fetchRequest) as! [Chat]).first
            
            guard chatToRemove != nil else {return false}
            
            try self.messagingLogic.deleteChat(
                chat: chatToRemove!,
                ownerUserId: self.sessionData.mxRestClient.credentials?.userId ?? "",
                context: self.context,
                locationLogic: self.sessionData.locationLogic,
                encryptionHandler: self.sessionData.encryptionHandler)
            
            print(failedMessage.1)
            self.viewError = IdentifiableError(failedMessage.1)
            return true
        }
    }
    
    var body: some View {
        switch self.rootState.state {
        case .loggedIn:
            return NavigationView{AnyView(
                ZStack {
                    ContentController(self.sessionData.mxRestClient.credentials?.userId ?? "Unknown User")
                        .onReceive(self.sessionData.$mxRestClient) { (newData) in
                            self.newRestClientReceived(newData)
                        }
                        .onReceive(self.sessionData.locationLogic.$currentLocation) { (newLocation) in
                            async { _ = try await(self.newLocationReceived(newLocation)) }
                        }
                    Text("").hidden().alert(item: self.$viewError) { viewError -> Alert in
                        ErrorAlert(viewError: viewError)
                    }
                }
            )
                
            }
        case .loggedOut:
            return NavigationView{AnyView(LogInController()
                .modifier(AdaptsToKeyboard())
                .onReceive(self.sessionData.$mxRestClient) { (newData) in
                self.newRestClientReceived(newData)
                }
            )}
        }
        
    }
}
