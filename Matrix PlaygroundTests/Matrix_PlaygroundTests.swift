//
//  Matrix_PlaygroundTests.swift
//  Matrix PlaygroundTests
//
//  Created by Matthew Roche on 03/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import XCTest

@testable import Matrix_Maps

import Mockingjay
import MatrixSDK
import CoreLocation
import CoreData
import Then
import KeychainSwift

public extension NSManagedObject {

    convenience init(usedContext: NSManagedObjectContext) {
        let name = String(describing: type(of: self))
        let entity = NSEntityDescription.entity(forEntityName: name, in: usedContext)!
        self.init(entity: entity, insertInto: usedContext)
    }

}

class Matrix_PlaygroundTests: XCTestCase {
    
    let accessToken = "fakeAccessToken"
    var mxRestClient: MXRestClient?
    var credentials: MXCredentials?
    var secondMXRestClient: MXRestClient?
    var secondCredentials: MXCredentials?
    let keychain = KeychainSwift.init(keyPrefix: "testingMatrixMaps")
    
    // E2E Variables
    var firstE2EKeychain: KeychainSwift?
    var firstE2ECredentials: MXCredentials?
    var firstE2EMXRestClient: MXRestClient?
    var firstE2EEncryptionHandler: EncryptionHandler?
    var secondE2EKeychain: KeychainSwift?
    var secondE2ECredentials: MXCredentials?
    var secondE2EMXRestClient: MXRestClient?
    var secondE2EEncryptionHandler: EncryptionHandler?
    
    let container = NSPersistentContainer(name: "UserModel", managedObjectModel: managedObjectModel)
    var storeDescription = NSPersistentStoreDescription()
    
    var testUser: UserDetails?
    
    static let managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: UserDetails.self)])!
        return managedObjectModel
    }()

    override func setUpWithError() throws {
        
        //self.clearAllData()
        
        credentials = MXCredentials(homeServer: "https://matrix-client.matrix.org", userId: "@testUser1:matrix.org", accessToken: "fakeAccessToken")
        credentials!.deviceId = "testdevice"
        credentials!.homeServer = "https://matrix-client.matrix.org"
        mxRestClient = MXRestClient(credentials: credentials!, unrecognizedCertificateHandler: nil)
        
        secondCredentials = MXCredentials(homeServer: "https://matrix-client.matrix.org", userId: "@testUser2:matrix.org", accessToken: "fakeAccessToken")
        secondCredentials!.deviceId = "testdevice"
        secondMXRestClient = MXRestClient(credentials: secondCredentials!, unrecognizedCertificateHandler: nil)
        
        //Set up core data
        storeDescription = NSPersistentStoreDescription()
        storeDescription.type = NSInMemoryStoreType
        storeDescription.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [storeDescription]
        container.loadPersistentStores(completionHandler: {(loadedStoreDescription, error) in
            if let error = error as NSError? {
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }
            
            //Create test user
            let obj = NSEntityDescription.insertNewObject(forEntityName: "UserDetails", into: self.container.viewContext)
            obj.setValue("@testUser1:matrix.org", forKey: "userId")
            self.testUser = obj as? UserDetails
            do {
                try self.container.viewContext.save()
            } catch {
                print("Error handling saving testUser")
            }
        })
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        self.clearAllData()
    }
    
    func clearAllData() {
        self.keychain.delete("encryptionAccount")
        self.keychain.delete("encryptionDevice")
        self.keychain.delete("encryptionSessions")
        self.keychain.delete("encryptionRecipientDevices")
        self.keychain.clear()
        
        do {
            
            let chatFetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: "Chat")
            chatFetchRequest.includesPropertyValues = false // Only fetch the managedObjectID (not the full object structure)
            if let chatFetchResults = try self.container.viewContext.fetch(chatFetchRequest) as? [Chat] {

                for result in chatFetchResults {
                    self.container.viewContext.delete(result)
                }

            }
        } catch {
            
        }
    }
    
    func testEncryptingAMessage() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully encrypts a message")
        
        self.clearAllData()
        
        async {
            
            let recipient = EncryptedMessageRecipient.init(userName: self.secondCredentials!.userId!, deviceName: "testdevice")
            let recipientAccount = OLMAccount.init(newAccount: ())
            let recipientDevice = try recipientAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let recipientSignedKeys = recipientAccount?.generateSignedOneTimeKeys(count: 1, credentials: (self.secondCredentials)!)
            let recipientSignedKeyName = recipientSignedKeys?.first?.key
            let recipientSignedKey = [
                recipientSignedKeyName!: recipientSignedKeys![recipientSignedKeyName!]!
            ]
            
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            
            // Fake API response for keys query
            let claimUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/query"
            let claimMessageData: NSDictionary = [
                "device_keys": [
                    recipient.userName: [
                        recipient.deviceName: recipientDevice?.jsonDictionary()
                    ]
                ],
                "failures": []
            ]
            self.stub(uri(claimUriValue), json(claimMessageData, status: 200))
            
            // Fake API response for keys claim
            let queryUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/claim"
            let queryMessageData: NSDictionary = [
              "failures": [],
              "one_time_keys": [
                recipient.userName: [
                  "testdevice": recipientSignedKey
                ]
              ]
            ]
            self.stub(uri(queryUriValue), json(queryMessageData, status: 200))
            
            // Fake API response for message sent
            let txnId = "32"
            let sendUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sendToDevice/matrixmaps.location/\(txnId)"
            let sendMessageData: NSDictionary = [:]
            self.stub(uri(sendUriValue), json(sendMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            print("Init complete")
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            print("Device creation complete")
            
            // Test sending message
            let outcome = try await(encryptionHandler.handleSendMessage(recipients: [recipient], message: "Test Message", txnId: txnId))
            let successUsers = outcome.success.map {$0.userName}
            print(successUsers)
            XCTAssertEqual(successUsers.contains((self.secondMXRestClient?.credentials.userId)!), true)
            
            print("Message send complete")
            
            expectation.fulfill()
            
            
                
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testDecryptingAMessage() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully decrypts a message")
        
        async {
            
            let testMessageContent = "Test message content"
            
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Find recipient keys
            let recipientIdentityKey = encryptionHandler.device?.identityKey
            // An AAAAAQ OTK is always created in the first round
            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
            
            // Set up sender and encrypt message
            let senderAccount = OLMAccount.init(newAccount: ())
            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let senderSession = try OLMSession.init(
                outboundSessionWith: senderAccount,
                theirIdentityKey: recipientIdentityKey,
                theirOneTimeKey: recipientOTKey)
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice!,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice!)
            
            // Fake API response for sync
            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
            let syncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": wrappedSenderMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
            
            let syncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let decryptedMessage = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessage[EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId)], testMessageContent)
            XCTAssertEqual(encryptionHandler.oneTimeKeyCount, 1)
            
            print("Message decrypt complete")
            
            expectation.fulfill()
            
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func createE2EUsers() throws  -> Promise<Void> {
        async {
            // Create E2E Users
            // - First
            self.firstE2EKeychain = KeychainSwift.init(keyPrefix: "testingMatrixMapsFirst")
            self.firstE2ECredentials = try await((self.mxRestClient?.loginPromise(
                username: "@matrix_maps_test1:matrix.org",
                password: "matrix_maps_test1"))!)
            self.firstE2EMXRestClient = MXRestClient.init(credentials: self.firstE2ECredentials!, unrecognizedCertificateHandler: nil)
            self.firstE2EEncryptionHandler = try EncryptionHandler.init(keychain: self.firstE2EKeychain! , mxRestClient: self.firstE2EMXRestClient!)
            let _ = try await(self.firstE2EEncryptionHandler!.createAndUploadDeviceKeys())
            // - Second
            self.secondE2EKeychain = KeychainSwift.init(keyPrefix: "testingMatrixMapsSecond")
            self.secondE2ECredentials = try await((self.mxRestClient?.loginPromise(
              username: "@matrix_maps_test2:matrix.org",
              password: "matrix_maps_test2"))!)
            self.secondE2EMXRestClient = MXRestClient.init(credentials: self.secondE2ECredentials!, unrecognizedCertificateHandler: nil)
            self.secondE2EEncryptionHandler = try EncryptionHandler.init(
                keychain: self.secondE2EKeychain!,
                mxRestClient: self.secondE2EMXRestClient!)
            let _ = try await(self.secondE2EEncryptionHandler!.createAndUploadDeviceKeys())
        }
    }
    
    func testSimpleE2E() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully sends and receives a message through Matrix")
        
        async {
            
            if (self.firstE2ECredentials == nil) {
                try await(self.createE2EUsers())
            }
            
            // Send message from first device to second
            let recipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test2:matrix.org",
                deviceName: self.secondE2ECredentials!.deviceId!)
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [recipient], message: "Test message", txnId: nil))
            
            // Receive message
            let syncResponse = try await(self.secondE2EMXRestClient!.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let decrypedMessages = try await(self.secondE2EEncryptionHandler!.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)], "Test message")
            
            print("Message decrypt complete")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func test2XUnidirectionalE2E() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully sends and receives two unidirectional messages through Matrix")
        
        async {
            
            if (self.firstE2ECredentials == nil) {
                try await(self.createE2EUsers())
            }
            
            // Send message from first device to second
            let recipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test2:matrix.org", deviceName: self.secondE2ECredentials!.deviceId!)
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [recipient], message: "Test message", txnId: nil))
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [recipient], message: "Second test message", txnId: nil))
            
            // Receive message
            let syncResponse = try await(self.secondE2EMXRestClient!.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let decrypedMessages = try await(self.secondE2EEncryptionHandler!.handleSyncResponse(syncResponse: syncResponse))
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(decrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)], "Second test message")
            
            print("Message decrypt complete")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testBidirectionalE2E() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully sends and receives two bidirectional messages through Matrix")
        
        async {
            
            if (self.firstE2ECredentials == nil) {
                try await(self.createE2EUsers())
            }
            
            // Send message from first device to second
            let firstRecipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test2:matrix.org", deviceName: self.secondE2ECredentials!.deviceId!)
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [firstRecipient], message: "Test message", txnId: nil))
            
            // Receive message
            let firstSyncResponse = try await(self.secondE2EMXRestClient!.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let firstDecrypedMessages = try await(self.secondE2EEncryptionHandler!.handleSyncResponse(syncResponse: firstSyncResponse))
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(firstDecrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)], "Test message")
            
            // Send message from second device to first
            let secondRecipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)
            try await(self.secondE2EEncryptionHandler!.handleSendMessage(
                recipients: [secondRecipient],
                message: "Another test message",
                txnId: nil))
            
            // Receive message
            let secondSyncResponse = try await(self.firstE2EMXRestClient!.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let secondDecrypedMessages = try await(self.firstE2EEncryptionHandler!.handleSyncResponse(syncResponse: secondSyncResponse))
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(secondDecrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test2:matrix.org", deviceName: self.secondE2ECredentials!.deviceId!)], "Another test message")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testAlteredSenderDevice() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully sends and receives a unidirectional message through Matrix after the sender has altered their device")
        
        async {
            
            if (self.firstE2ECredentials == nil) {
                try await(self.createE2EUsers())
            }
            
            // Send message from first device to second
            let firstRecipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test2:matrix.org", deviceName: self.secondE2ECredentials!.deviceId!)
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [firstRecipient], message: "Test message", txnId: nil))
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [firstRecipient], message: "Second test message", txnId: nil))
            
            // Receive message
            let firstSyncResponse = try await(self.secondE2EMXRestClient!.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let firstDecrypedMessages = try await(self.secondE2EEncryptionHandler!.handleSyncResponse(syncResponse: firstSyncResponse))
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(firstDecrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)], "Second test message")
            
            let initialFirstDeviceId = self.firstE2ECredentials!.deviceId
            let initialFromToken = firstSyncResponse.nextBatch
            
            // Alter senders device
            self.firstE2EKeychain = KeychainSwift.init(keyPrefix: "testingMatrixMapsFirstRepeat")
            self.firstE2ECredentials = try await((self.mxRestClient?.loginPromise(
                username: "@matrix_maps_test1:matrix.org",
                password: "matrix_maps_test1"))!)
            self.firstE2EMXRestClient = MXRestClient.init(credentials: self.firstE2ECredentials!, unrecognizedCertificateHandler: nil)
            self.firstE2EEncryptionHandler = try EncryptionHandler.init(keychain: self.firstE2EKeychain! , mxRestClient: self.firstE2EMXRestClient!)
            let _ = try await(self.firstE2EEncryptionHandler!.createAndUploadDeviceKeys())
            
            XCTAssertNotEqual(initialFirstDeviceId, self.firstE2ECredentials?.deviceId)
            
            // Send another message
            let repeatRecipient = EncryptedMessageRecipient.init(
                userName: "@matrix_maps_test2:matrix.org", deviceName: self.secondE2ECredentials!.deviceId!)
            try await(self.firstE2EEncryptionHandler!.handleSendMessage(recipients: [repeatRecipient], message: "Another test message", txnId: nil))
            
            // Receive message
            let repeatSyncResponse = try await(self.secondE2EMXRestClient!.syncPromise(
                fromToken: initialFromToken,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let repeatDecrypedMessages = try await(self.secondE2EEncryptionHandler!.handleSyncResponse(syncResponse: repeatSyncResponse))
            
            XCTAssertEqual(repeatDecrypedMessages[EncryptedMessageRecipient(userName: "@matrix_maps_test1:matrix.org", deviceName: self.firstE2ECredentials!.deviceId!)], "Another test message")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testFailPreKeyWithIncorrectIdentityKey() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of prekey fails when incorrect key passed in wrapper")
        
        async {
            
            let testMessageContent = "Test message content"
            
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Find recipient keys
            let recipientIdentityKey = encryptionHandler.device?.identityKey
            // An AAAAAQ OTK is always created in the first round
            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
            
            // Set up sender and encrypt message
            let senderAccount = OLMAccount.init(newAccount: ())
            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let senderSession = try OLMSession.init(
                outboundSessionWith: senderAccount,
                theirIdentityKey: recipientIdentityKey,
                theirOneTimeKey: recipientOTKey)
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice!,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice!)
            let mutatedWrappedSenderMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSenderMessage.algorithm,
                "ciphertext": wrappedSenderMessage.ciphertext,
                "senderKey": wrappedSenderMessage.senderKey.reversed(),
                "senderDevice": wrappedSenderMessage.senderDevice
            ])
            
            // Fake API response for sync
            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
            let syncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": mutatedWrappedSenderMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
            
            let syncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId!)), false)
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFailStandardMessageWithIncorrectIdentityKey() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of standard message fails when incorrect key passed in wrapper")
        
        async {
            
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Find recipient keys
            let recipientIdentityKey = encryptionHandler.device?.identityKey
            // An AAAAAQ OTK is always created in the first round
            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
            
            // Set up sender and encrypt message
            let senderAccount = OLMAccount.init(newAccount: ())
            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let senderSession = try OLMSession.init(
                outboundSessionWith: senderAccount,
                theirIdentityKey: recipientIdentityKey,
                theirOneTimeKey: recipientOTKey)
            let firstEncryptedMessage = try senderSession.encryptMessageWithPayload(
                "Test",
                senderDevice: senderDevice!,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(firstEncryptedMessage, senderDevice: senderDevice!)
            
            // Fake API response for sync
            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
            let syncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": wrappedSenderMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
            
            let syncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let _ = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            // Set up return standard message
            let recipientSession = encryptionHandler.getSession(user: senderDevice!.userId, device: senderDevice!.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            
            // Finally, start creating mutated standard message
            let _ = try senderSession.decryptMessage(standardReply)
            let secondStandardMessage = try senderSession.encryptMessageWithPayload(
                "A mutated reply",
                senderDevice: senderDevice!,
                recipientDevice: encryptionHandler.device!)
            
            XCTAssertEqual(secondStandardMessage.type, OLMMessageType.message)
            
            let wrappedSecondStandardMessageMessage = try encryptionLogic.wrapOLMMessage(secondStandardMessage, senderDevice: senderDevice!)
            let mutatedWrappedSecondStandardMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSecondStandardMessageMessage.algorithm,
                "ciphertext": wrappedSecondStandardMessageMessage.ciphertext,
                "senderKey": wrappedSecondStandardMessageMessage.senderKey.reversed(),
                "senderDevice": wrappedSecondStandardMessageMessage.senderDevice
            ])
            // Fake API response for sync
            let secondSyncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": mutatedWrappedSecondStandardMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(secondSyncMessageData, status: 200))
            
            let secondSyncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: secondSyncResponse))
            print(decryptedMessages)
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId!)), false)
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFailPreKeyMessageWithIncorrectPayloadKey() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of prekey message fails when incorrect key passed in payload")
        
        async {
            let testMessageContent = "Test message content"
            
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Find recipient keys
            let recipientIdentityKey = encryptionHandler.device?.identityKey
            // An AAAAAQ OTK is always created in the first round
            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
            
            // Set up sender and encrypt message
            let senderAccount = OLMAccount.init(newAccount: ())
            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let senderSession = try OLMSession.init(
                outboundSessionWith: senderAccount,
                theirIdentityKey: recipientIdentityKey,
                theirOneTimeKey: recipientOTKey)
            let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice!.jsonDictionary())
            mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] = (mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] as! String).lowercased()
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: mutatedSenderDevice!,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice!)
            
            // Fake API response for sync
            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
            let syncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": wrappedSenderMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
            
            let syncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId!)), false)
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFailStandardMessageWithIncorrectPayloadKey() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of standard message fails when incorrect key passed in payload")
        
        async {
            // Fake API response for keys upload
            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
            let uploadMessageData: NSDictionary = [
              "one_time_key_counts": [
                "curve25519": 10,
                "signed_curve25519": 20
              ]
            ]
            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: self.keychain ,
                mxRestClient: self.mxRestClient!)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Find recipient keys
            let recipientIdentityKey = encryptionHandler.device?.identityKey
            // An AAAAAQ OTK is always created in the first round
            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
            
            // Set up sender and encrypt message
            let senderAccount = OLMAccount.init(newAccount: ())
            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
            let senderSession = try OLMSession.init(
                outboundSessionWith: senderAccount,
                theirIdentityKey: recipientIdentityKey,
                theirOneTimeKey: recipientOTKey)
            let firstEncryptedMessage = try senderSession.encryptMessageWithPayload(
                "Test",
                senderDevice: senderDevice!,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(firstEncryptedMessage, senderDevice: senderDevice!)
            
            // Fake API response for sync
            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
            let syncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": wrappedSenderMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
            
            let syncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let _ = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            // Set up return standard message
            let recipientSession = encryptionHandler.getSession(user: senderDevice!.userId, device: senderDevice!.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            
            // Finally, start creating mutated standard message
            let _ = try senderSession.decryptMessage(standardReply)
            let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice!.jsonDictionary())
            mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] = (mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] as! String).lowercased()
            let secondStandardMessage = try senderSession.encryptMessageWithPayload(
                "A mutated reply",
                senderDevice: mutatedSenderDevice!,
                recipientDevice: encryptionHandler.device!)
            
            XCTAssertEqual(secondStandardMessage.type, OLMMessageType.message)
            
            let wrappedSecondStandardMessageMessage = try encryptionLogic.wrapOLMMessage(secondStandardMessage, senderDevice: senderDevice!)
            // Fake API response for sync
            let secondSyncMessageData: NSDictionary = [
                "account_data": [],
                "next_batch": "s72595_4483_1934",
                "presence": [],
                "rooms": [
                  "invite": [],
                  "join": [],
                  "leave":[]
                ],
                "to_device": [
                    "events": [
                        [
                            "content": wrappedSecondStandardMessageMessage.nsDictionary,
                            "sender": senderDevice!.userId!,
                            "type": "matrixmaps.location"
                        ]
                    ]
                ],
                "device_one_time_keys_count": [
                    "signed_curve25519": 1
                ]
            ]
            self.stub(uri(syncUriValue), json(secondSyncMessageData, status: 200))
            
            let secondSyncResponse = try await((self.mxRestClient?.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))!)
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: secondSyncResponse))
            print(decryptedMessages)
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId!)), false)
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testFailInvalidPreKeyReceived() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Creation of session fails when invalid prekey passed")
        
        async {
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
        

}
