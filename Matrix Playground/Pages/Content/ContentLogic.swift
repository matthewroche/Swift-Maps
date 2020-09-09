//
//  ContentLogic.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 22/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import CoreData
import SwiftMatrixSDK
import Then
import SwiftLocation
import CoreLocation

class ContentLogic {
    
    let messagingLogic = MessagingLogic()
    
    //Note: Need to be able to force txnId for testing
    /// startChat
    /// Starts a new chat with a remote user
    /// Note: Need to be able to force txnId for testing
    /// - Parameters:
    ///   - invitedUser: A String containing the username of the remote user
    ///   - invitedDevice: A String containing the device ID of the remote user
    ///   - userDetails: A USerDetails object referring to the local user
    ///   - context: The NSManagedObjectContext for CoreData storage
    ///   - mxRestClient: The MXRestClient over which to perform network requests
    ///   - locationLogic: The LocationLogic object enabling location updates
    ///   - forcedTxnId: An optional String allowing the transaction ID to be overridden (required for testing)
    /// - Returns: A Promise returning true if successful
    public func startChat (
        invitedUser: String,
        invitedDevice: String,
        userDetails: UserDetails,
        context: NSManagedObjectContext,
        encryptionHandler: EncryptionHandler,
        locationLogic: LocationLogic) -> Promise<Bool> {
        return Promise {resolve, reject in
            async {
                guard invitedUser.count > 0 else {throw ContentError.noUsername}
                guard invitedDevice.count > 0 else {throw ContentError.noDevice}
                try await(self.messagingLogic.startChat(
                    invitedUser: invitedUser,
                    invitedDevice: invitedDevice,
                    userDetails: userDetails,
                    context: context,
                    encryptionHandler: encryptionHandler))
                _ = try await(locationLogic.startTrackingLocation())
                resolve(true)
            }.onError {error in
                reject(error)
            }
        }
    }
    
    
    /// Sync
    /// Performs synchronisation with the server
    /// - Parameters:
    ///   - mxRestClient: The MXRestClient over which to perform network requests
    ///   - context: The NSManagedObjectContext for CoreData storage
    ///   - ownerUser: A USerDetails object referring to the local user
    ///   - encryptionHandler: The EncryptionHandler object enabling decryption of the messages
    /// - Returns: A Promise returning true if successful
    public func sync (mxRestClient: MXRestClient, context: NSManagedObjectContext, ownerUser: UserDetails, encryptionHandler: EncryptionHandler) -> Promise<Bool> {
        async {
            try await(self.messagingLogic.sync(mxRestClient: mxRestClient, context: context, ownerUser: ownerUser, encryptionHandler: encryptionHandler))
        }
    }
       
    
    /// logout
    /// Performs a simple logout preserving device data
    /// - Parameter sessionData: A SessionData object
    /// - Returns: Void
    func logout (sessionData: SessionData) -> Void {
        sessionData.locationLogic.stopTrackingLocation()
        sessionData.keychain.delete("credentials")
        sessionData.mxRestClient = MXRestClient()
    }
    
    /// logoutAndDeleteData
    ///  Performs a logout and deletes all local and remote data relating to the device
    /// - Parameters:
    ///   - sessionData: A SessionData object
    ///   - context: The NSManagedObjectContext for CoreData storage
    ///   - password: A String contining the user's password
    /// - Returns: A promise returning true if successful
    func logoutAndDeleteData (sessionData: SessionData, context: NSManagedObjectContext, password: String) throws -> Promise<Bool> {
        async {
            
            guard password.count > 0 else { throw ContentError.passwordDoesNotExist }
            
            let userId = sessionData.mxRestClient.credentials?.userId ?? ""
            let deviceId = sessionData.mxRestClient.credentials?.deviceId ?? ""
            
            // Delete remote device
            let authSession = try await(sessionData.mxRestClient.getSessionPromise(toDeleteDevice: deviceId))
            let authDetails = [
                "session": authSession.session ?? "",
                "type": "m.login.password",
                "user": userId,
                "identifier": [
                  "type": "m.id.user",
                  "user": userId
                ],
                "password": password
            ] as [String : Any]
            do {
                try await(sessionData.mxRestClient.deleteDevicePromise(deviceId, authParameters: authDetails))
            } catch {
                print("Failed deleting remote device")
                throw error
            }
            
            
            // Delete coreData user
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserDetails")
            let recipientPredicate = NSPredicate(format: "userId == %@", userId )
            fetchRequest.predicate = recipientPredicate
            let results = try context.fetch(fetchRequest) as? [UserDetails] ?? []
            if results.count != 0 {
                context.delete(results[0])
            }
            
            sessionData.locationLogic.stopTrackingLocation()
            sessionData.keychain.delete("credentials")
            sessionData.encryptionHandler.clearEncryptionState()
            sessionData.mxRestClient = MXRestClient()
            
            return true
        }
    }
    
}
