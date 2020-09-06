//
//  SceneDelegate.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import UIKit
import SwiftUI
import CoreData

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?
    var sessionData: SessionData?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Use this method to optionally configure and attach the UIWindow `window` to the provided UIWindowScene `scene`.
        // If using a storyboard, the `window` property will automatically be initialized and attached to the scene.
        // This delegate does not imply the connecting scene or session are new (see `application:configurationForConnectingSceneSession` instead).

        //Inject session data into appdelegate to enable set up during lunchscreen
        
        let appDelegate = (UIApplication.shared.delegate as! AppDelegate)
        sessionData = appDelegate.sessionData
        
        // Create the SwiftUI view that provides the window contents.
        guard let context = (UIApplication.shared.delegate as? AppDelegate)?.persistentContainer.viewContext else {
            fatalError("Unable to read managed object context.")
        }
        // Check a user exists in CoreData to match any in keychain
        if (sessionData!.mxRestClient != nil && sessionData!.mxRestClient?.credentials.userId != nil) {
            let userFetchRequest: NSFetchRequest<UserDetails> = UserDetails.fetchRequest()
            userFetchRequest.sortDescriptors = []
            userFetchRequest.predicate = NSPredicate(format: "userId == %@", sessionData!.mxRestClient!.credentials.userId!)
            do {
                let userFetchedResults = try context.fetch(userFetchRequest)
                if userFetchedResults.count == 0 {
                    print("Unable to find owner user for details in keycahin - deleting keychain")
                    sessionData!.keychain.delete("credentials")
                    sessionData!.mxRestClient = nil
                }
            } catch {
                // Unable to access CoreData for some reason - just return
            }
            
            
        }
        
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        let rootView = RootView().environment(\.managedObjectContext, context)

        // Use a UIHostingController as window root view controller.
        if let windowScene = scene as? UIWindowScene {
            let window = UIWindow(windowScene: windowScene)
            window.rootViewController = UIHostingController(rootView: rootView.environmentObject(sessionData!))
            self.window = window
            window.makeKeyAndVisible()
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not neccessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
        (UIApplication.shared.delegate as? AppDelegate)?.saveContext()
    }


}


struct SceneDelegate_Previews: PreviewProvider {
    static var previews: some View {
        PreviewWrapper()
    }
    
    struct PreviewWrapper: View {
        
        var sessionData = SessionData()
        
        var body: some View {
            
            return RootView().environmentObject(sessionData)
        }
    }
}
