//
//  SessionData.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 08/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import SwiftMatrixSDK
import KeychainSwift
import SwiftLocation
import CoreData

class SessionData: ObservableObject {
    
    @Published var keychain = KeychainSwift()
    @Published var locationLogic = LocationLogic()
    @Published var encryptionHandler = EncryptionHandler()
    @Published var mxRestClient = MXRestClient() {
        didSet {
            handleNewMXRestClient()
        }
    }
    
    /// handleNewMXRestClient
    /// Handles data manipulation when MXRestClient is edited and failure scenarios
    private func handleNewMXRestClient() {
        print("New mxRestClient")
        if mxRestClient.credentials?.userId != nil {
            do {
                print("Creating encryption handler")
                self.encryptionHandler = try EncryptionHandler(keychain: self.keychain, mxRestClient: self.mxRestClient)
            } catch {
                // This should never fail, but if it does nuke everything and start again.
                print("Unable to init encryptionHandler")
                print(error)
                // Delete all stored chats for this user
                do {
                    let context = (UIApplication.shared.delegate as? AppDelegate)!.persistentContainer.viewContext
                    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
                    let ownerPredicate = NSPredicate(format: "ownerUser.userId == %@", mxRestClient.credentials?.userId ?? "")
                    fetchRequest.predicate = ownerPredicate
                    let results = try context.fetch(fetchRequest) as? [Chat] ?? []
                    for chat in results {
                        context.delete(chat)
                    }
                    
                } catch {
                    print("Unable to delete chats for this user whilst nuking data")
                }
                self.keychain.clearAllForPrefix("\(self.mxRestClient.credentials?.userId ?? "")_")
                self.mxRestClient = MXRestClient()
            }
            
        } else {
            print("Setting encryption handler to nil")
            self.encryptionHandler = EncryptionHandler()
        }
    }
    
    
}
