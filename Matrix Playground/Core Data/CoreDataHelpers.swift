//
//  CoreDataHelpers.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 03/09/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation
import CoreData
import SwiftUI

public func doesUserExistLocally(localUsername: String, context: NSManagedObjectContext) throws -> Bool {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "UserDetails")
    fetchRequest.predicate = NSPredicate(format: "userId == %@", localUsername)
    let results = try context.fetch(fetchRequest) as! [UserDetails]
    return results.count > 0
}

public func existingChatForUserDevice(
    localUsername: String,
    remoteUsername: String,
    remoteDeviceId: String,
    context: NSManagedObjectContext) throws -> Chat? {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
    let recipientUsernamePredicate = NSPredicate(format: "recipientUser == %@", remoteUsername)
    let recipientDeviceIdPredicate = NSPredicate(format: "recipientDevice == %@", remoteDeviceId)
    let ownerPredicate = NSPredicate(format: "ownerUser.userId == %@", localUsername)
    fetchRequest.predicate = NSCompoundPredicate(
        type: .and,
        subpredicates: [recipientUsernamePredicate, recipientDeviceIdPredicate, ownerPredicate])
    let results = try context.fetch(fetchRequest) as! [Chat]
    print("Number of existing chats: \(results.count)")
    return results.first ?? nil
}

public func getAllRegisteredLocationRecipients(localUsername: String, context: NSManagedObjectContext) throws -> [Chat] {
    let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
    let ownerPredicate = NSPredicate(format: "ownerUser.userId == %@", localUsername as String)
    let sendingPredicate = NSPredicate(format: "sending == YES")
    fetchRequest.predicate = NSCompoundPredicate(
        type: .and,
        subpredicates: [sendingPredicate, ownerPredicate])
    let results = try context.fetch(fetchRequest) as! [Chat]
    return results
}
