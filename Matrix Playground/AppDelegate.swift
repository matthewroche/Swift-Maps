//
//  AppDelegate.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import UIKit
import CoreData
import SwiftMatrixSDK
import CoreLocation
import SwiftLocation
import KeychainSwift

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var sessionData = SessionData()

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        //
        // Ensure location authorisation
        //
        LocationManager.shared.requireUserAuthorization(.always)
        
        
        //
        // LOADING CREDENTIALS FROM KEYCHAIN
        //
        // Check KeyChain for credentials
        loadCredentialsFromKeychain(sessionData)
        
        
        //
        // Handle background location updates after app has been quit
        //
        handleBackgroundLocationUpdates(launchOptions)
        
        
        //
        // Check for chats requiring location updates and start location tracking appropriately
        //
        startTrackingUpdatesIfRequired(sessionData, persistentContainer)
        
        
        return true
    }

    // MARK: UISceneSession Lifecycle

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        // Called when a new scene session is being created.
        // Use this method to select a configuration to create the new scene with.
        return UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
    }

    func application(_ application: UIApplication, didDiscardSceneSessions sceneSessions: Set<UISceneSession>) {
        // Called when the user discards a scene session.
        // If any sessions were discarded while the application was not running, this will be called shortly after application:didFinishLaunchingWithOptions.
        // Use this method to release any resources that were specific to the discarded scenes, as they will not return.
    }
    
//    Set up CoreData
    lazy var persistentContainer: NSPersistentContainer = {
        /*
         The persistent container for the application. This implementation
         creates and returns a container, having loaded the store for the
         application to it. This property is optional since there are legitimate
         error conditions that could cause the creation of the store to fail.
        */
        let container = NSPersistentContainer(name: "UserModel")
        // Don't load core data if testing
        if NSClassFromString("XCTest") == nil {
            container.loadPersistentStores(completionHandler: { (storeDescription, error) in
                if let error = error as NSError? {
                    // Replace this implementation with code to handle the error appropriately.
                    // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.

                    /*
                     Typical reasons for an error here include:
                     * The parent directory does not exist, cannot be created, or disallows writing.
                     * The persistent store is not accessible, due to permissions or data protection when the device is locked.
                     * The device is out of space.
                     * The store could not be migrated to the current model version.
                     Check the error message to determine what the actual problem was.
                     */
                    
                    // There is always an error in preview mode.
                    if ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1" {
                        return
                    }
                    
                    fatalError("Unresolved error \(error), \(error.userInfo)")
                }
                
                
                
            })
        }
        return container
    }()
    
    // MARK: - Core Data Saving support

    func saveContext() {
        let context = persistentContainer.viewContext
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        if context.hasChanges {
            do {
                try context.save()
            } catch {
                // Replace this implementation with code to handle the error appropriately.
                // fatalError() causes the application to generate a crash log and terminate. You should not use this function in a shipping application, although it may be useful during development.
                let nserror = error as NSError
                fatalError("Unresolved error \(nserror), \(nserror.userInfo)")
            }
        }
    }
    
    func handleBackgroundLocationUpdates(_ launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        guard launchOptions != nil else {return}
        if let _ = launchOptions?[UIApplication.LaunchOptionsKey.location] {
            print("App launched with location updates")
            // Check for presence of a chat requiring location updates
            do {
                let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
                fetchRequest.predicate = NSPredicate(format: "sending == YES")
                let results = try persistentContainer.viewContext.fetch(fetchRequest) as! [Chat]
                if results.count != 0 {
                    print("Starting tracking due to UIApplication.LaunchOptionsKey.location")
                    sessionData.locationLogic.startTrackingLocation().start()
                }
            } catch {
                print("Error starting tracking updates")
            }
        }
    }
    
    func loadCredentialsFromKeychain(_ sessionData: SessionData) {
        var credentials: KeychainCredentials?
        var credentialsString: String?
        var mxCredentials: MXCredentials?
        
        credentialsString = sessionData.keychain.get("credentials")
        guard credentialsString != nil else {return}
        
        // Decode credentials
        do {
            credentials = try JSONDecoder().decode(KeychainCredentials.self, from: Data(credentialsString!.utf8))
        } catch {
            // Stored credentials are invalid, delete them
            print("Error decoding credentials")
            print(error)
            sessionData.keychain.delete("credentials")
        }
        guard credentials != nil else {return}
        
        //Set up Matrix with credentials
        mxCredentials = MXCredentials(
            homeServer: credentials!.homeServer,
            userId: credentials!.userId,
            accessToken: credentials!.accessToken
        )
        guard mxCredentials != nil else {return}
        mxCredentials!.deviceId = credentials!.deviceId
        // Set up rest client
        sessionData.mxRestClient = MXRestClient(credentials: mxCredentials!, unrecognizedCertificateHandler: nil)
    }
    
    
    func startTrackingUpdatesIfRequired(_ sessionData: SessionData, _ persistentContainer: NSPersistentContainer) {
        do {
            let userId = sessionData.mxRestClient.credentials?.userId ?? ""
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
            let ownerPredicate = NSPredicate(format: "ownerUser.userId == %@", userId)
            let sendingPredicate = NSPredicate(format: "sending == YES")
            fetchRequest.predicate = NSCompoundPredicate(
                type: .and,
                subpredicates: [sendingPredicate, ownerPredicate])
            let results = try persistentContainer.viewContext.fetch(fetchRequest) as! [Chat]
            if results.count != 0 {
                sessionData.locationLogic.startTrackingLocation().start()
            }
        } catch {
            print("Error starting tracking updates")
        }
    }


}

