//
//  Encryption.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 08/07/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import OLMKit
import Then
import SwiftMatrixSDK
import KeychainSwift
import OLMKit

public class EncryptionHandler {
    
    // The local user's account
    public var account: OLMAccount?
    // The local user's device
    public var device: MXDeviceInfo?
    // The number of one time keys existing on the server
    public var oneTimeKeyCount: Int? = nil
    // A map of sessions that have been created
    private var sessions = MXUsersDevicesMap<OLMSession>()
    // A map of remote devices which we know about
    private var recipientDevices = MXUsersDevicesMap<MXDeviceInfo>()
    // Entry point into lower level functions
    private let encryptionLogic = EncryptionLogic()
    // A link to keychain
    private let keychain: KeychainSwift
    // The key used for serialisation of OLM data
    private let key: Data
    // A link to the rest client
    private let mxRestClient: MXRestClient
    // A link to utilities required by OLM
    private let olmUtility = OLMUtility()
    // the vent type which we send and respond to
    private let eventType = "matrixmaps.location"
    
    init() {
        self.keychain = KeychainSwift()
        self.mxRestClient = MXRestClient()
        self.key = Data()
    }
    
    init(keychain: KeychainSwift, mxRestClient: MXRestClient) throws {
        
        self.keychain = keychain
        self.mxRestClient = mxRestClient
        self.key = (mxRestClient.credentials?.userId ?? "").data(using: String.Encoding.utf8) ?? Data()
        
        if mxRestClient.credentials?.userId != nil {
            
            
            let account = keychain.get(createKeycahinStorageName(suffix: "encryptionAccount"))
            let device = keychain.get(createKeycahinStorageName(suffix: "encryptionDevice"))
            let sessionsString = keychain.get(createKeycahinStorageName(suffix: "encryptionSessions"))
            let recipientDevicesString = keychain.get(createKeycahinStorageName(suffix: "encryptionRecipientDevices"))
            
            print("Setting up Encryption Handler")
            
            do {
                
                if account != nil {
                    print("Creating account")
                    self.account = try OLMAccount.init(serializedData: account!, key: self.key)
                } else {
                    clearEncryptionState()
                }
                if device != nil {
                    print("Creating device")
                    let deviceData = device!.data(using: String.Encoding.utf8)
                    let deviceJSON = try JSONSerialization.jsonObject(with: deviceData!) as? [AnyHashable : Any] ?? [:]
                    self.device = MXDeviceInfo.init(fromJSON: deviceJSON)
                } else {
                    clearEncryptionState()
                }
                if sessionsString != nil {
                    print("Creating sessions")
                    let sessionsData = sessionsString!.data(using: String.Encoding.utf8) ?? Data()
                    let sessionsStringObject = try JSONSerialization.jsonObject(with: sessionsData) as? [String: [String: String]] ?? [:]
                    var sessionsObject =  [String: [String: OLMSession]]()
                    //Iterate through each session and convert to object
                    for (user, deviceSession) in sessionsStringObject {
                        for (device, session) in deviceSession {
                            sessionsObject[user] = [:]
                            sessionsObject[user]![device] = try OLMSession.init(serializedData: session, key: self.key)
                        }
                    }
                    self.sessions = MXUsersDevicesMap.init(map: sessionsObject)
                }
                if recipientDevicesString != nil {
                    print("Creating recipient devices")
                    let recipientDevicesData = recipientDevicesString!.data(using: String.Encoding.utf8) ?? Data()
                    let recipientDevicesStringObject = try JSONSerialization.jsonObject(with: recipientDevicesData) as? [String: [String: String]] ?? [:]
                    var recipientDevicesObject = [String: [String: MXDeviceInfo]]()
                    //Iterate through each device and convert to object
                    for (user, deviceDevice) in recipientDevicesStringObject {
                        for (device, deviceData) in deviceDevice {
                            recipientDevicesObject[user] = [:]
                            recipientDevicesObject[user]![device] = try MXDeviceInfo.init(fromJSONString: deviceData)
                        }
                    }
                    //Ensure each device in recipientDevices has a matching session
                    for (user, deviceDevice) in recipientDevicesStringObject {
                        for (device, _) in deviceDevice {
                            guard self.sessions.object(forDevice: device, forUser: user) != nil else {throw EncryptionError.storedSessionsAndRecipientDevicesDoNotMatch}
                        }
                    }
                    self.recipientDevices = MXUsersDevicesMap.init(map: recipientDevicesObject)
                }
            } catch {
                clearEncryptionState()
                throw error
            }
        }
        
    }
    
    private func createKeycahinStorageName(suffix: String) -> String {
        return "\(mxRestClient.credentials?.userId ?? "")_\(suffix)"
    }
    
    private func saveEncryptionState() throws {
        
        guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
        
        if (self.account != nil) {
            let accountString = try self.account!.serializeData(withKey: self.key)
            self.keychain.set(accountString, forKey: createKeycahinStorageName(suffix: "encryptionAccount"), withAccess: .accessibleWhenUnlocked)
        }
        
        if (self.device != nil) {
            let deviceString = self.device!.jsonString()!
            self.keychain.set(deviceString, forKey: createKeycahinStorageName(suffix: "encryptionDevice"), withAccess: .accessibleWhenUnlocked)
        }
        
        var sessionsStringObject =  [String: [String: String]]()
        for (user, deviceSession) in self.sessions.map {
            for (device, session) in deviceSession {
                sessionsStringObject[user] = [:]
                sessionsStringObject[user]![device] = try session.serializeData(withKey: self.key)
            }
        }
        let sessionsData = try JSONSerialization.data(withJSONObject: sessionsStringObject)
        let sessionsString = String(data: sessionsData, encoding: String.Encoding.utf8)!
        self.keychain.set(sessionsString, forKey: createKeycahinStorageName(suffix: "encryptionSessions"), withAccess: .accessibleWhenUnlocked)
        
        var recipientDevicesStringObject = [String: [String: String]]()
        for (user, deviceDevice) in self.recipientDevices.map {
            for (device, deviceData) in deviceDevice {
                recipientDevicesStringObject[user] = [:]
                recipientDevicesStringObject[user]![device] = deviceData.jsonString()
            }
        }
        let recipientDevicesData = try JSONSerialization.data(withJSONObject: recipientDevicesStringObject )
        let recipientDevicesString = String(data: recipientDevicesData, encoding: String.Encoding.utf8)!
        self.keychain.set(recipientDevicesString, forKey: createKeycahinStorageName(suffix: "encryptionRecipientDevices"), withAccess: .accessibleWhenUnlocked)
    }
    
    func clearEncryptionState() {
        self.keychain.clearAllForPrefix("\(mxRestClient.credentials?.userId ?? "")_encryption")
        self.account = nil
        self.device = nil
        self.sessions = MXUsersDevicesMap<OLMSession>()
        self.recipientDevices = MXUsersDevicesMap<MXDeviceInfo>()
    }
    
    func createAndUploadDeviceKeys() throws -> Promise<Bool> {
        return Promise { resolve, reject in
            async {
                guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
                guard (self.account == nil) else {throw EncryptionError.existingAccount}
                guard (self.device == nil) else {throw EncryptionError.existingAccount}
                self.account = OLMAccount.init(newAccount: ())!
                let (device, otkCount) = try await(
                    self.encryptionLogic.initialiseDeviceKeys(account: self.account!, mxRestClient: self.mxRestClient))
                self.device = device
                self.oneTimeKeyCount = otkCount["signed_curve25519"] as? Int
                try self.saveEncryptionState()
                resolve(true)
            }.onError { error in
                reject(error)
            }
        }
    }
    
    func handleUpdateOneTimeKeys(_ numberOfKeys: UInt) throws -> Promise<Bool> {
        return Promise { resolve, reject in
            async {
                guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
                guard self.account != nil else {throw EncryptionError.noAccount}
                guard self.device != nil else {throw EncryptionError.noAccount}
                let otkCount = try await(self.encryptionLogic.uploadNewOneTimeKeys(account: self.account!, mxRestClient: self.mxRestClient, numberOfKeys: numberOfKeys))
                self.oneTimeKeyCount = otkCount["signed_curve25519"] as? Int
                try self.saveEncryptionState()
                resolve(true)
            }.onError { error in
                reject(error)
            }
        }
    }
    
    func handleSendMessage(recipients: [EncryptedMessageRecipient], message: String, txnId: String?) throws ->
        Promise<EncryptedSentMessageOutcome> {
        return Promise { resolve, reject in
            async {
                
                //Ensure encryption keys have been set up
                guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
                guard self.account != nil else {throw EncryptionError.noAccount}
                guard self.device != nil else {throw EncryptionError.noAccount}
                
                let returnedResults = EncryptedSentMessageOutcome()
                
                // Ensure session exists for each user
                var filteredRecipients = recipients
                for user in filteredRecipients {
                    if self.sessions.object(forDevice: user.deviceName, forUser: user.userName) == nil {
                        // If not create one
                        do {
                            _ = try await(self.createNewSessionForUser(recipient: user))
                        } catch {
                            print(error)
                            print("Unable to create session for user: \(user.combinedName)")
                            returnedResults.failure.append((user, error))
                            // Unable to create a session for this user - remove them from senders list
                            if let index = filteredRecipients.firstIndex(of: user) {
                                filteredRecipients.remove(at: index)
                            }
                        }
                        
                        
                    }
                }
                
                let messagesMap = MXUsersDevicesMap<NSDictionary>()
                for user in filteredRecipients {
                    do {
                        try await(self.ensureDeviceAndSessionExistForRecipient(recipient: user))
                        let recipientDeviceInfo = self.recipientDevices.object(forDevice: user.deviceName, forUser: user.userName)!
                        let session = self.sessions.object(forDevice: user.deviceName, forUser: user.userName)!
                        // Encrypt message with payload
                        let encryptedMessage = try session.encryptMessageWithPayload(
                            message,
                            senderDevice: self.device!,
                            recipientDevice: recipientDeviceInfo)
                        // Wrap encrypted message
                        let wrappedMessage = try self.encryptionLogic.wrapOLMMessage(encryptedMessage, senderDevice: self.device!)
                        messagesMap.setObject(wrappedMessage.nsDictionary, forUser: user.userName, andDevice: user.deviceName)
                    } catch {
                        print("Unable to encrypt message for user: \(user.combinedName)")
                        returnedResults.failure.append((user, error))
                        // Unable to create a session for this user - remove them from senders list
                        if let index = filteredRecipients.firstIndex(of: user) {
                            filteredRecipients.remove(at: index)
                        }
                    }
                }
                
                returnedResults.success = filteredRecipients
                
                // Send message
                try await(self.mxRestClient.sendDirectToDevicePromise(
                    eventType: self.eventType,
                    contentMap: messagesMap,
                    txnId: txnId ?? UUID().uuidString)
                )
                
                // Store session state
                try self.saveEncryptionState()
                
                print(returnedResults)
                resolve(returnedResults)
            }.onError { error in
                reject(error)
            }
        }
    }
    
    func handleSyncResponse(syncResponse: MXSyncResponse) throws -> Promise<[EncryptedMessageRecipient: String]> {
        return Promise {resolve, reject in
            async {
                
                //Ensure encryption keys have been set up
                guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
                guard self.account != nil else {throw EncryptionError.noAccount}
                guard self.device != nil else {throw EncryptionError.noAccount}
                
                var decryptedMessages = [EncryptedMessageRecipient:String]()
                // Ensure toDevice messages exist
                if syncResponse.toDevice != nil {
                    decryptedMessages = self.decryptMessagesFromSyncResponse(toDeviceMessages: syncResponse.toDevice!)
                }
                print(decryptedMessages)
                
                //Update OTK count
                if syncResponse.deviceOneTimeKeysCount != nil {
                    self.oneTimeKeyCount = syncResponse.deviceOneTimeKeysCount["signed_curve25519"] as? Int
                }
                
                // Update OTKs if required
                if self.oneTimeKeyCount ?? 0 < 10 {
                    _ = try self.handleUpdateOneTimeKeys(10)
                }
                
                // Store session state
                try self.saveEncryptionState()
                
                resolve(decryptedMessages)
                
            }.onError { error in
                reject(error)
            }
        }
    }
    
    func removeSessionForUser(recipient: EncryptedMessageRecipient) -> Void {
        self.sessions.removeObject(forUser: recipient.userName, andDevice: recipient.deviceName)
        self.recipientDevices.removeObject(forUser: recipient.userName, andDevice: recipient.deviceName)
    }
    
    private func ensureDeviceAndSessionExistForRecipient(recipient: EncryptedMessageRecipient) -> Promise<Bool> {
        
        func nukeStoredDeviceAndSessionThenCreateNew() -> Promise<Bool> {
            return Promise {resolve, reject in
                async {
                    self.removeSessionForUser(recipient: recipient)
                    try await(self.createNewSessionForUser(recipient: recipient))
                    resolve(true)
                }.onError { error in
                    reject(error)
                }
            }
        }
        
        return Promise {resolve, reject in
            async {
                if (self.sessions.object(forDevice: recipient.deviceName, forUser: recipient.userName)) == nil {
                    _ = try await(nukeStoredDeviceAndSessionThenCreateNew())
                    resolve(true)
                }
                if (self.recipientDevices.object(forDevice: recipient.deviceName, forUser: recipient.userName)) == nil {
                    _ = try await(nukeStoredDeviceAndSessionThenCreateNew())
                    resolve(true)
                }
                resolve(true)
            }.onError { error in
                reject(error)
            }
        }
    }
    
    private func decryptMessagesFromSyncResponse(toDeviceMessages: MXToDeviceSyncResponse) -> [EncryptedMessageRecipient: String] {
        
        var returnedMessages = [EncryptedMessageRecipient: String]()
        
        guard toDeviceMessages.events != nil else {return returnedMessages}
        
        // For each message
        for event in toDeviceMessages.events {
            
            do {
                guard event.type == self.eventType else {continue}
                let wrappedMessage = EncryptedMessageWrapper.init(dictionary: event.content!)
                let encryptedMessage = try self.encryptionLogic.unwrapOLMMessage(wrappedMessage)
                
                let sender = EncryptedMessageRecipient(userName: event.sender, deviceName: wrappedMessage.senderDevice)
            
                if (encryptedMessage.type == .preKey) {
                    // If we've never seen this device before
                    print("Handling pre key message")
                    print("Message age \(event.ageLocalTs)")
                    returnedMessages[sender] = try self.handlePreKeyMessage(
                        encryptedMessage: encryptedMessage,
                        senderId: event.sender,
                        wrappedIdentityKey: wrappedMessage.senderKey)
                } else {
                    // We must have seen this device before
                    print("Handling standard message")
                    returnedMessages[sender] = try self.handleStandardMessage(
                        encryptedMessage: encryptedMessage,
                        senderId: event.sender,
                        senderDevice: wrappedMessage.senderDevice,
                        wrappedIdentityKey: wrappedMessage.senderKey)
                }
            } catch {
                // There was an error decrypting this message, but continue to try decrypting others
                print(error)
                continue
            }
        }
        
        return returnedMessages
    }
    
    private func handlePreKeyMessage(encryptedMessage: OLMMessage, senderId: String, wrappedIdentityKey: String) throws -> String {
        
        // Create new session
        let session = try OLMSession.init(inboundSessionWith: self.account, oneTimeKeyMessage: encryptedMessage.ciphertext)
        //Decrypt message
        let (decryptedMessage, senderDevice) = try session.decryptMessageWithPayload(
            encryptedMessage,
            recipientDevice: self.device!
        )
        // Check encrypted sender key matches that in wrapper
        guard senderDevice.identityKey == wrappedIdentityKey else {throw EncryptionError.noMatchingIdentityKey}
        // Save device and session
        self.sessions.setObject(session, forUser: senderId, andDevice: senderDevice.deviceId)
        self.recipientDevices.setObject(senderDevice, forUser: senderId, andDevice: senderDevice.deviceId)
        return decryptedMessage
    }
    
    private func handleStandardMessage(encryptedMessage: OLMMessage, senderId: String, senderDevice: String, wrappedIdentityKey: String) throws -> String {
        // Find previous session and device
        let session = self.sessions.object(forDevice: senderDevice, forUser: senderId)
        let senderDevice = self.recipientDevices.object(forDevice: senderDevice, forUser: senderId)
        guard session != nil else {throw EncryptionError.noSession}
        guard senderDevice != nil else {throw EncryptionError.noSession}
        guard wrappedIdentityKey == senderDevice!.identityKey else {throw EncryptionError.inboundSessionDoesntMatch}
        //Decrypt message with validation from previously known details
        do {
            let decryptedMessage = try session!.decryptMessageWithPayload(
                encryptedMessage,
                recipientDevice: self.device!,
                senderDevice: senderDevice!
            )
            // We should never receive another prekey message with the prekey used to create this session, so we can safely delete it
            // This will unfortunately throw an error every time more than one standard message is received,
            // but unfortunately there is no sensible way to check whether a key has already been deleted
            self.account!.removeOneTimeKeys(for: session)
            return decryptedMessage
        } catch {
            throw error
        }
    }
    
    // Validates a prekey
    private func validatePreKey(recipient: EncryptedMessageRecipient, recipientDevice: MXDeviceInfo, preKey: MXKey) throws -> Void {
        // Check signatures on prekey
        let keyDeviceString = "ed25519:" + recipientDevice.deviceId!
        guard preKey.signatures.object(forDevice: keyDeviceString, forUser: recipient.userName) != nil else {
            print("No signature available for pre key validation")
            throw EncryptionError.noSignature
        }
        
        do {
            try self.olmUtility.verifyEd25519Signature(
                preKey.signatures.object(forDevice: keyDeviceString, forUser: recipient.userName) as String,
                key: recipientDevice.fingerprint,
                message: MXCryptoTools.canonicalJSONData(forJSON: preKey.signalableJSONDictionary))
        } catch {
            print("Prekey failed verification")
            throw EncryptionError.prekeyFailedVerification
        }
    }
    
    // Creates a new sessions for a recipient device
    public func createNewSessionForUser(recipient: EncryptedMessageRecipient) -> Promise<Bool> {
        return Promise {resolve, reject in
            async {
                
                //Ensure encryption keys have been set up
                guard self.mxRestClient.credentials?.userId != nil else {throw EncryptionError.noCredentialsAvailable}
                guard self.account != nil else {throw EncryptionError.noAccount}
                guard self.device != nil else {throw EncryptionError.noAccount}
                
                // Obtaining keys for all devices for user
                let downloadedKeys = try await(self.mxRestClient.downloadKeysPromise(forUsers: [recipient.userName]))
                
                // Check requested device exists
                if downloadedKeys.deviceKeys.object(forDevice: recipient.deviceName, forUser: recipient.userName) == nil {
                    print("Downloaded keys does not contain device")
                    throw EncryptionError.deviceDoesNotExist
                }
                let recipientDevice = downloadedKeys.deviceKeys.object(
                    forDevice: recipient.deviceName,
                    forUser: recipient.userName)!
                
                // Need to format key request correctly
                let preKeysRequestDetails = MXUsersDevicesMap<NSString>()
                preKeysRequestDetails.setObject("signed_curve25519", forUser: recipient.userName, andDevice: recipient.deviceName)
                
                // Download prekeys
                let downloadedPreKeys = try await(self.mxRestClient.claimOneTimeKeysPromise(for: preKeysRequestDetails))
                
                // Check rqeuested keys exist for specified device
                if !((downloadedPreKeys.oneTimeKeys.deviceIds(forUser: recipient.userName) ?? []).contains(recipient.deviceName)) {
                    throw EncryptionError.noPreKeysAvailable
                }
                
                // Find correct device and keys
                let preKey = downloadedPreKeys.oneTimeKeys!.object(forDevice: recipient.deviceName, forUser: recipient.userName)!
                
                print(recipientDevice)
                print(preKey)
                
                // Validate Prekey
                try self.validatePreKey(recipient: recipient, recipientDevice: recipientDevice, preKey: preKey)
                
                print("Pre Key Validated")
                
                // Create session
                let session = try OLMSession.init(
                    outboundSessionWith: self.account,
                    theirIdentityKey: recipientDevice.identityKey,
                    theirOneTimeKey: preKey.value)
                
                print("Session created")
                
                //Save session and device
                self.recipientDevices.setObject(recipientDevice, forUser: recipient.userName, andDevice: recipient.deviceName)
                self.sessions.setObject(session, forUser: recipient.userName, andDevice: recipient.deviceName)
                
                try self.saveEncryptionState()
                
                print("Device and sessions saved")
                
                resolve(true)
                
            }.onError { error in
                print(error)
                reject(error)
            }
        }
    }

}

#if DEBUG
extension EncryptionHandler {
    public func getSession(user: String, device: String) -> OLMSession? {
        return self.sessions.object(forDevice: device, forUser: user)
    }
}
#endif
