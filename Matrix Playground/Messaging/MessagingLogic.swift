//
//  messaging.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 24/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import MatrixSDK
import CoreData
import CoreLocation
import Then

public class MessagingLogic {
    
    let messageType = "matrixmaps.location"
    let messageVersion = 1
    
    //Note: Need to be able to force txnId for testing
    /// startChat
    /// Starts a chat with a given user
    /// - Parameters:
    ///   - invitedUser: A String defining which user to start the chat with
    ///   - invitedDevice: A String defining which device to start the chat with
    ///   - userDetails: The UserDetails object of the sending user
    ///   - context: The NSManagedObjectCOntext for the local device
    /// - Returns: A Promise resolving to true if successful
    public func startChat (
        invitedUser: String,
        invitedDevice: String,
        userDetails: UserDetails,
        context: NSManagedObjectContext,
        encryptionHandler: EncryptionHandler) -> Promise<Bool> {
        return Promise {resolve, reject in
            async {
                guard invitedUser.count > 0 else {throw MessagingError.noUsername}
                guard invitedDevice.count > 0 else {throw MessagingError.noDevice}
                if try existingChatForUserDevice(localUsername: userDetails.userId!, remoteUsername: invitedUser, remoteDeviceId: invitedDevice, context: context) != nil {
                    throw MessagingError.duplicateChat
                }
                
                let _ = try await(encryptionHandler.createNewSessionForUser(recipient: EncryptedMessageRecipient(userName: invitedUser, deviceName: invitedDevice)))
                
                try self.createNewChat(
                    recipientUser: invitedUser,
                    recipientDevice: invitedDevice,
                    context: context,
                    userDetails: userDetails)
                
                resolve(true)
            }.onError {error in
                reject(error)
            }
        }
    }
    
    /// sync
    /// Performs sychronisation with the server
    /// - Parameters:
    ///   - mxRestClient: The MXRestClient through which to route the request
    ///   - context: The NSManagedObjectCOntext for the local device
    ///   - ownerUser: The UserDetails object relating to the logged in user locally
    ///   - encryptionHandler: The EncryptionHandler object relating encryption to the logged in user
    /// - Returns: A Promise resolving to true if successful
    public func sync (
        mxRestClient: MXRestClient,
        context: NSManagedObjectContext,
        ownerUser: UserDetails,
        encryptionHandler: EncryptionHandler) -> Promise<Bool> {
        async {
            print("Syncing with token: \(ownerUser.syncFromToken ?? "No token")")
            let syncResponse = try await(
                mxRestClient.syncPromise(
                    fromToken: ownerUser.syncFromToken, //This can be nil if not set for initial sync
                    serverTimeout: 0,
                    clientTimeout: 5000,
                    setPresence: nil)
            )
            try DispatchQueue.main.sync {
                try self.processSyncResponse(
                    syncResponse: syncResponse,
                    context: context,
                    ownerUser: ownerUser,
                    encryptionHandler: encryptionHandler)
            }
            // If we received exactly 100 events then we reached the server limit of messages to receive
            // We need to sync again to ensure we are up to date
            if (syncResponse.toDevice != nil && syncResponse.toDevice.events != nil) {
                print("\(syncResponse.toDevice.events.count) events received")
                if (syncResponse.toDevice.events.count == 100) {
                    try await(self.sync(
                    mxRestClient: mxRestClient,
                    context: context,
                    ownerUser: ownerUser,
                    encryptionHandler: encryptionHandler))
                }
            } else {
                print("No events received.")
            }
            return true
        }
    }
    
    /// processSyncResponse
    /// - Parameters:
    ///   - syncResponse: The MXSyncResponse bject which we are processing
    ///   - context: The NSManagedObjectCOntext for the local device
    ///   - ownerUser: The UserDetails object relating to the logged in user locally
    ///   - encryptionHandler: The EncryptionHandler object relating encryption to the logged in user
    /// - Returns: Void
    public func processSyncResponse(
        syncResponse: MXSyncResponse,
        context: NSManagedObjectContext,
        ownerUser: UserDetails,
        encryptionHandler: EncryptionHandler) throws -> Void {
        
        // Check direct to device events received
        if (syncResponse.toDevice != nil && syncResponse.toDevice.events != nil) {
            if (syncResponse.toDevice.events.count > 0) {
                
                // Filter for correct event type and order
                syncResponse.toDevice.events = syncResponse.toDevice.events.filter({ event -> Bool in
                    return event.type == self.messageType
                })
                syncResponse.toDevice.events.sort { (lhs, rhs) -> Bool in
                    lhs.age > rhs.age
                }
                
                // Decrypt events
                let (decryptedEvents, alteredSessions) = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
                
                // For each message
                for (sender, eventContent) in decryptedEvents {
                    //Ensure message correctly formatted
                    let content: MatrixMapsMessage?
                    do {
                        content = try MatrixMapsMessage(eventContent)
                        guard content != nil  else {continue}
                    } catch {
                        // Invalid data was received - skip message
                        continue
                    }
                    
                    let existingChat = try existingChatForUserDevice(localUsername: ownerUser.userId!, remoteUsername: sender.userName, remoteDeviceId: sender.deviceName, context: context)
                    if (existingChat != nil) {
                        // Chat already exists - modify it
                        existingChat!.lastSeen = Date().timeIntervalSince1970
                        existingChat!.lastReceivedLatitude = content!.location[0]
                        existingChat!.lastReceivedLongitude = content!.location[1]
                        existingChat!.receiving = true
                        existingChat!.alteredSession = alteredSessions.contains(sender)
                        try context.save()
                    }
                    
                    else {
                        // Need to create new chat
                        print("Creating new chat")
                        let newChat = Chat.init(context: context)
                        newChat.ownerUser = ownerUser
                        newChat.recipientUser = sender.userName
                        newChat.recipientDevice = sender.deviceName
                        newChat.lastSeen = Date().timeIntervalSince1970
                        newChat.lastReceivedLatitude = content!.location[0]
                        newChat.lastReceivedLongitude = content!.location[1]
                        newChat.receiving = true
                        try context.save()
                    }
                }
            }
        }
        
        // Store sync token
        if (syncResponse.nextBatch != nil) {
            ownerUser.syncFromToken = syncResponse.nextBatch
            try context.save()
        }
        
    }
    
    /// updateAllRecipientsWithNewLocation
    /// Handles sending of location update to all recipients registerd in CoreData model
    /// - Parameters:
    ///   - location: The updated location
    ///   - encryptionHandler: The encryptionHandler enabling encryption and sending of the messages
    /// - Returns: Void
    public func updateAllRecipientsWithNewLocation(
        location: CLLocation,
        encryptionHandler: EncryptionHandler,
        context: NSManagedObjectContext) -> Promise<EncryptedSentMessageOutcome> {
        async {
            
            guard encryptionHandler.device != nil else { throw MessagingError.notLoggedIn}
            guard encryptionHandler.device!.userId != nil else { throw MessagingError.notLoggedIn}
            
            // Get all recipients
            let recipients = try getAllRegisteredLocationRecipients(localUsername: encryptionHandler.device!.userId! as String, context: context)
            
            if recipients.count > 0 {
                
                // Create message to send
                let directMessage = MatrixMapsMessage(location, version: self.messageVersion)
                
                // Create array of recipients
                var recipientArray = [EncryptedMessageRecipient]()
                for recipient in recipients {
                    if (recipient.recipientUser != nil && recipient.recipientDevice != nil) {
                        recipientArray.append(EncryptedMessageRecipient.init(
                            userName: recipient.recipientUser!,
                            deviceName: recipient.recipientDevice!))
                    }
                }
                
                let outcomeForRecipients = try await(encryptionHandler.handleSendMessage(
                    recipients: recipientArray,
                    message: try directMessage.toJSONString(),
                    txnId: UUID().uuidString))
                
                print("Success sending")
                
                return outcomeForRecipients
                
            }
            
            return EncryptedSentMessageOutcome()
            
        }
    }
    
    /// createNewChat
    /// Creates a new chat in the CoreData model
    /// - Parameters:
    ///   - recipientUser: The recipient username
    ///   - recipientDevice: The recipient deviceID
    ///   - context: The NSManagedObjectCOntext for the local device
    ///   - userDetails: The UserDetails object for the logged in user
    /// - Returns: Void
    public func createNewChat(recipientUser: String, recipientDevice: String, context: NSManagedObjectContext, userDetails: UserDetails) throws -> Void {
        guard recipientUser.count > 0 else {throw MessagingError.noUsername}
        guard recipientDevice.count > 0 else {throw MessagingError.noDevice}
        let newChat = Chat.init(context: context)
        newChat.recipientUser = recipientUser
        newChat.recipientDevice = recipientDevice
        newChat.lastSeen = NSDate().timeIntervalSince1970
        newChat.sending = true
        DispatchQueue.main.async {
            do {
                userDetails.addToChats(newChat)
                try context.save()
            } catch {
                print("Unable to save new chat")
            }
        }

    }
    
    
    /// updateChat
    /// Updates an existing chat
    /// - Parameters:
    ///   - chat: The new Chat object to update
    ///   - ownerUserId: A String containing the userID of the local user
    ///   - context: The NSManagedObjectCOntext for the local device
    ///   - locationLogic: The LocationLogic object providing updates to the user's location
    /// - Returns: Void
    public func updateChat(chat: Chat, ownerUserId: String, context: NSManagedObjectContext, locationLogic: LocationLogic) throws -> Void {
        try context.save()
        try checkLocationTrackingRequired(ownerUserId: ownerUserId, locationLogic: locationLogic, context: context)
    }
    
    
    
    /// deletesChat
    /// Deletes an existing chat
    /// - Parameters:
    ///   - chat: The chat to delete
    ///   - ownerUserId: A String containing the userID of the local user
    ///   - context: The NSManagedObjectContext for the local device
    ///   - locationLogic: The LocationLogic object providing updates to the user's location
    ///   - encryptionHandler: The instance of EncryptionHandler that manages the session for this user
    /// - Returns: Void
    public func deleteChat(chat: Chat, ownerUserId: String, context: NSManagedObjectContext, locationLogic: LocationLogic) throws -> Void {
        guard chat.recipientUser != nil else {throw MessagingError.noUsername}
        guard chat.recipientDevice != nil else {throw MessagingError.noDevice}
        //Delete chat
        context.delete(chat)
        try context.save()
        try checkLocationTrackingRequired(ownerUserId: ownerUserId, locationLogic: locationLogic, context: context)
    }
    
    
    /// checkLocationTrackingRequired
    /// Checks whether any chats the user owns require location tracking and stops tracking if there are not any.
    /// - Parameters:
    ///   - ownerUserId: A String describing the userId of the owner (local) user
    ///   - locationLogic: A LocationLogic struct providing access to location updates
    ///   - context: The NSManagedObjectContext for the local device
    /// - Returns: Void
    private func checkLocationTrackingRequired(ownerUserId: String, locationLogic: LocationLogic, context: NSManagedObjectContext) throws -> Void {
        guard ownerUserId.count > 0 else {throw MessagingError.noUsername}
        // Check that chats requiring location to be sent still exist
        let recipients = try getAllRegisteredLocationRecipients(localUsername: ownerUserId, context: context)
        if recipients.count == 0 {
            print("Stopping location tracking")
            locationLogic.stopTrackingLocation()
        }
    }
    
}
