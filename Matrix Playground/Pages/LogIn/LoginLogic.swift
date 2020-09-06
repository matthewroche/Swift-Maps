//
//  LoginLogic.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 15/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import CoreData
import SwiftMatrixSDK
import Then
import OLMKit

struct KeychainCredentials: Codable {
    public let accessToken: String
    public let deviceId: String
    public let homeServer: String
    public let userId: String
}

class LoginLogic {
    
    public func login(username: String, password: String, context: NSManagedObjectContext, sessionData: SessionData, serverAddress: String) -> Promise<Bool> {
        
        async {
            
            // Check inputs exist
            guard username.count > 0 else {throw LoginError.noUsername}
            guard password.count > 0 else {throw LoginError.noPassword}
            
            let homeServerURL = URL.init(string: serverAddress)
            
            guard homeServerURL != nil else {throw LoginError.invalidServerAddress}
            
            // Create client for log in
            let mxRestClient = MXRestClient(homeServer: homeServerURL!, unrecognizedCertificateHandler: nil)
            
            // Log In
            let credentials = try await(mxRestClient.loginPromise(
                type: MXLoginFlowType.password,
                username: username,
                password: password))
            
            //Ensure valid credentials received
            guard credentials.accessToken != nil else {throw LoginError.invalidServerResponse}
            guard credentials.deviceId != nil else {throw LoginError.invalidServerResponse}
            guard credentials.homeServer != nil else {throw LoginError.invalidServerResponse}
            guard credentials.userId != nil else {throw LoginError.invalidServerResponse}
            
            // Encode credentials for keychain
            let encodedCredentials = try self.encodeCredentialsForKeychain(credentials: credentials)
            
            // Create new user if non exists
            if !(try doesUserExistLocally(localUsername: credentials.userId!, context: context)) {
                do {
                    let newUser = UserDetails.init(context: context)
                    newUser.userId = credentials.userId
                    try context.save()
                } catch {
                    throw LoginError.saveUserFailed
                }
            }
            
            let credentialedMXRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
            
            DispatchQueue.main.sync {
                sessionData.mxRestClient = credentialedMXRestClient
                sessionData.keychain.set(encodedCredentials, forKey: "credentials", withAccess: .accessibleWhenUnlocked)
            }
            
            try self.setUpEncryption(sessionData: sessionData)
            
            return true
            
        }
    }
    
    private func encodeCredentialsForKeychain(credentials: MXCredentials) throws -> Data {
        let encodableCredentials = KeychainCredentials(
            accessToken: credentials.accessToken!, deviceId: credentials.deviceId!,
            homeServer: credentials.homeServer!, userId: credentials.userId!)
        return try JSONEncoder().encode(encodableCredentials)
    }
    
    private func setUpEncryption(sessionData: SessionData) throws -> Void {
        // Needs to be after mxRestClient stored in session data so encryptionHandler is available
        guard sessionData.encryptionHandler != nil else {
            print("Encryption handler not available")
            throw LoginError.unableToSetUpEncryption
        }
        
        // If this is a brand new encryption handler, upload keys
        if (sessionData.encryptionHandler!.account == nil) {
            do {
                _ = try await(sessionData.encryptionHandler!.createAndUploadDeviceKeys())
            } catch {
                print(error)
                throw LoginError.unableToSetUpEncryption
            }
        }
    }
}
