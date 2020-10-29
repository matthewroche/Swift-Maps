//
//  ChatContoller.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 09/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import SwiftUI
import CoreData
import MapKit
import MatrixSDK

struct ChatController: View {
    
    var chatDetails: Chat
    
    @State private(set) var viewError: IdentifiableError?
    @State private var centerCoordinate = CLLocationCoordinate2D()
    @State private var locations = [MKPointAnnotation]()
    @State private var isExplanationTextShowing = false
    @State private var showingDeleteAlert = false
    @State private var showingStopTransmissionAlert = false
    @State private var alertItem: AlertItem?
    
    @Environment(\.managedObjectContext) var context
    @Environment(\.presentationMode) var presentationMode: Binding<PresentationMode>
    @EnvironmentObject var sessionData: SessionData
    
    let messagingLogic = MessagingLogic()
    
    init(chatDetails: Chat) {
        self.chatDetails = chatDetails
        self._centerCoordinate = State(initialValue: CLLocationCoordinate2D(
            latitude: CLLocationDegrees(chatDetails.lastReceivedLatitude),
            longitude: CLLocationDegrees(chatDetails.lastReceivedLongitude)))
        let annotation = MKPointAnnotation()
        annotation.coordinate = self.centerCoordinate
        annotation.title = chatDetails.recipientUser
        annotation.subtitle = chatDetails.recipientDevice
        self._locations = State(initialValue: [annotation])
    }
    
    
    /// stopChat
    /// Deletes a chat from CoreData store
    func stopChat() {
        do {
            guard self.sessionData.mxRestClient.credentials?.userId != nil else {throw ChatError.notLoggedIn}
            try self.messagingLogic.deleteChat(
                chat: chatDetails,
                ownerUserId: self.sessionData.mxRestClient.credentials?.userId ?? "",
                context: self.context,
                locationLogic: self.sessionData.locationLogic,
                encryptionHandler: self.sessionData.encryptionHandler)
        } catch {
            print(error)
            self.viewError = IdentifiableError(error)
        }
        presentationMode.wrappedValue.dismiss()
    }
    
    /// cancelChangedSessionWarning
    /// Cancels the banner warning the user that the session was changed
    func cancelChangedSessionWarning() {
        do {
            guard self.sessionData.mxRestClient.credentials?.userId != nil else {throw ChatError.notLoggedIn}
            // If we're not receiving and don't wish to send any more hen just delete the chat
            chatDetails.alteredSession = false
            try messagingLogic.updateChat(
                chat: chatDetails,
                ownerUserId: self.sessionData.mxRestClient.credentials?.userId ?? "",
                context: self.context,
                locationLogic: self.sessionData.locationLogic)
        } catch {
            print(error)
            self.viewError = IdentifiableError(error)
        }
    }
    
    
    /// stopTransmission
    /// Stops the user transmitting thier location to a user, and deltes the chat if they are not receiving location updates
    func stopTransmission() {
        do {
            guard self.sessionData.mxRestClient.credentials?.userId != nil else {throw ChatError.notLoggedIn}
            // If we're not receiving and don't wish to send any more hen just delete the chat
            if (chatDetails.receiving == false) { self.stopChat() }
            chatDetails.sending = false
            try messagingLogic.updateChat(
                chat: chatDetails,
                ownerUserId: self.sessionData.mxRestClient.credentials?.userId ?? "",
                context: self.context,
                locationLogic: self.sessionData.locationLogic)
        } catch {
            print(error)
            self.viewError = IdentifiableError(error)
        }
    }
    
    /// startTransmission
    /// Begins transmission of location to a remote user
    func startTransmission() {
        do {
            guard self.sessionData.mxRestClient.credentials?.userId != nil else {throw ChatError.notLoggedIn}
            chatDetails.sending = true
            try messagingLogic.updateChat(
                chat: chatDetails,
                ownerUserId: self.sessionData.mxRestClient.credentials?.userId ?? "",
                context: self.context,
                locationLogic: self.sessionData.locationLogic)
            self.sessionData.locationLogic.startTrackingLocation().start()
        } catch {
            print(error)
            self.viewError = IdentifiableError(error)
        }
    }
    
    /// onTransmissionLongPress
    /// Handles display of explanation text
    func onTransmissionLongPress(inProgress: Bool) -> Void {
        self.isExplanationTextShowing = inProgress
    }
    
    
    /// handleOnAppear
    /// Handles synchronisation when the page is loaded
    func handleOnAppear() {
        guard self.sessionData.mxRestClient.credentials?.userId != nil else {return}
        
        let userFetchRequest = NSFetchRequest<NSManagedObject>(entityName: "UserDetails")
        userFetchRequest.predicate = NSPredicate(format: "userId == %@", self.sessionData.mxRestClient.credentials?.userId ?? "")
        var userFetchedResults = [UserDetails]()
        do {
            userFetchedResults = try self.context.fetch(userFetchRequest) as? [UserDetails] ?? []
        } catch {
            print("Unable to find owner user")
        }
        guard userFetchedResults.count > 0 else {
            print("Unable to find owner user")
            return
        }
        let userDetails = userFetchedResults.first!
        self.messagingLogic.sync(
            mxRestClient: self.sessionData.mxRestClient,
            context: self.context,
            ownerUser: userDetails,
            encryptionHandler: self.sessionData.encryptionHandler).then { (messageErrors) in
                if messageErrors.count > 0 {
                    self.viewError = IdentifiableError(ChatError.newSenderMessageErrors(messageErrors))
                }
            }
    }
    
    
    var body: some View {
        ZStack {
            ChatView(
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
                alertItem: $alertItem)
                .onAppear() { self.handleOnAppear() }
            Text("").hidden().alert(item: self.$viewError) { viewError -> Alert in
                    return ErrorAlert(viewError: viewError)
            }
        }
    }
}
