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

func createCredentialsKeychainAndRestClient(userId: String, accessToken: String, deviceName: String) -> (MXCredentials, KeychainSwift, MXRestClient) {
    let credentials = MXCredentials(homeServer: "https://matrix-client.matrix.org", userId: userId, accessToken: accessToken)
    credentials.deviceId = deviceName
    credentials.homeServer = "https://matrix-client.matrix.org"
    let keychain = KeychainSwift.init(keyPrefix: userId)
    let mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
    return (credentials, keychain, mxRestClient)
}

func createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: String, password: String) throws ->
    (MXCredentials, KeychainSwift, EncryptionHandler, MXRestClient) {
        let keychain = KeychainSwift.init(keyPrefix: userId)
        var mxRestClient = MXRestClient(homeServer: URL.init(string: "https://matrix-client.matrix.org")!, unrecognizedCertificateHandler: nil)
        let credentials = try await(mxRestClient.loginPromise(
            username: userId,
            password: password))
        mxRestClient = MXRestClient.init(credentials: credentials, unrecognizedCertificateHandler: nil)
        let encryptionHandler = try EncryptionHandler.init(keychain: keychain , mxRestClient: mxRestClient)
        let _ = try await(encryptionHandler.createAndUploadDeviceKeys())
        return (credentials, keychain, encryptionHandler, mxRestClient)
}

func createUserAccountDeviceAndKeys(credentials: MXCredentials) throws -> (EncryptedMessageRecipient, OLMAccount, MXDeviceInfo) {
    let user = EncryptedMessageRecipient.init(userName: credentials.userId!, deviceName: credentials.deviceId!)
    let account = OLMAccount.init(newAccount: ())
    let device = try account!.generateSignedDeviceKeys(credentials: credentials)
    return (user, account!, device)
}

func createSignedKeys(account: OLMAccount, credentials: MXCredentials) -> [String: [String: Any]] {
    let signedKeys = account.generateSignedOneTimeKeys(count: 1, credentials: credentials)
    let signedKeyName = signedKeys.first?.key ?? ""
    return [
        signedKeyName: signedKeys[signedKeyName]!
    ]
}

func createEncryptionAccountDeviceAndSession(credentials: MXCredentials, recipientIdentityKey: String, recipientOTKey: String) throws -> (OLMAccount, MXDeviceInfo, OLMSession) {
    let senderAccount = OLMAccount.init(newAccount: ())!
    let senderDevice = try senderAccount.generateSignedDeviceKeys(credentials: credentials)
    let senderSession = try createEncryptionSession(
        localAccount: senderAccount,
        remoteIdentityKey: recipientIdentityKey,
        remoteOTKey: recipientOTKey)
    return (senderAccount, senderDevice, senderSession)
}

func createEncryptionSession(localAccount: OLMAccount, remoteIdentityKey: String, remoteOTKey: String) throws -> OLMSession {
    return try OLMSession.init(
        outboundSessionWith: localAccount,
        theirIdentityKey: remoteIdentityKey,
        theirOneTimeKey: remoteOTKey)
}

func createEncryptionHandlerAndObtainKeys(keychain: KeychainSwift, mxRestClient: MXRestClient) throws -> (EncryptionHandler, String, String){
    let encryptionHandler = try EncryptionHandler.init(keychain: keychain, mxRestClient: mxRestClient)
    try await(encryptionHandler.createAndUploadDeviceKeys())
    let identityKey = (encryptionHandler.device?.identityKey)!
    // An AAAAAQ OTK is always created in the first round
    let otKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
    return (encryptionHandler, identityKey, otKey)
}

func e2eSendMessageFromUserToUser(recipient: EncryptedMessageRecipient, sendersHandler: EncryptionHandler,
                                  recipientsMxRestClient: MXRestClient, recipientsHandler: EncryptionHandler,
                                  messages: [String], lastSyncToken: String?) throws -> Promise<([EncryptedMessageRecipient: String], String)> {
    async {
        for message in messages {
            try await(sendersHandler.handleSendMessage(recipients: [recipient], message: message, txnId: nil))
        }
        // Receive message
        let syncResponse = try await(recipientsMxRestClient.syncPromise(
            fromToken: lastSyncToken ?? nil,
            serverTimeout: 5000,
            clientTimeout: 5000,
            setPresence: nil))
        return (try await(recipientsHandler.handleSyncResponse(syncResponse: syncResponse)), syncResponse.nextBatch)
    }
}

class Matrix_PlaygroundTests: XCTestCase {
    
    let container = NSPersistentContainer(name: "UserModel", managedObjectModel: managedObjectModel)
    var storeDescription = NSPersistentStoreDescription()
    var testUser: UserDetails?
    var lastE2ESyncToken: String?
    
    static let managedObjectModel: NSManagedObjectModel = {
        let managedObjectModel = NSManagedObjectModel.mergedModel(from: [Bundle(for: UserDetails.self)])!
        return managedObjectModel
    }()

    override func setUpWithError() throws {
        
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
        let keychain = KeychainSwift()
        keychain.clear()
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
    
    func createStub(uriValue: String, data: NSDictionary, status: Int) {
        self.stub(uri(uriValue), json(data, status: status))
    }
    
    func createKeysUploadStub() {
        let uri = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testDevice"
        let data: NSDictionary = [
            "one_time_key_counts": [
              "curve25519": 10,
              "signed_curve25519": 20
            ]
        ]
        self.createStub(uriValue: uri, data: data, status: 200)
    }
    
    func createKeysQueryStub(credentials: MXCredentials, device: MXDeviceInfo) {
        let uri = "https://matrix-client.matrix.org/_matrix/client/r0/keys/query"
        let data: NSDictionary = [
            "device_keys": [
                credentials.userId: [
                    credentials.deviceId: device.jsonDictionary()
                ]
            ],
            "failures": [:]
        ]
        self.createStub(uriValue: uri, data: data, status: 200)
    }
    
    func createKeysClaimStub(credentials: MXCredentials, signedKey: [String: [String: Any]]) {
        let uri = "https://matrix-client.matrix.org/_matrix/client/r0/keys/claim"
        let data: NSDictionary = [
            "failures": [:],
            "one_time_keys": [
                credentials.userId: [
                    credentials.deviceId: signedKey
                ]
            ]
        ]
        self.createStub(uriValue: uri, data: data, status: 200)
    }
    
    func createSendToDeviceStub(txnId: String) {
        let uri = "https://matrix-client.matrix.org/_matrix/client/r0/sendToDevice/matrixmaps.location/\(txnId)"
        let data: NSDictionary = [:]
        self.createStub(uriValue: uri, data: data, status: 200)
    }
    
    func createSyncStub(wrappedMessage: EncryptedMessageWrapper, senderDevice: MXDeviceInfo) {
        let uri = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
        let data: NSDictionary = [
            "account_data": [:],
            "next_batch": "s72595_4483_1934",
            "presence": [:],
            "rooms": [
                "invite": [:],
                "join": [:],
                "leave":[:]
            ],
            "to_device": [
                "events": [
                    [
                        "content": wrappedMessage.nsDictionary,
                        "sender": senderDevice.userId!,
                        "type": "matrixmaps.location"
                    ]
                ]
            ],
            "device_one_time_keys_count": [
                "signed_curve25519": 1
            ]
        ]
        self.createStub(uriValue: uri, data: data, status: 200)
    }
    
    func testEncryptingAMessage() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully encrypts a message")
        
        async {
            
            let (recipientCredentials, recipientKeychain, recipientMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            
            let (recipientUser, recipientAccount, recipientDevice) = try createUserAccountDeviceAndKeys(
                credentials: recipientCredentials)
            
            let recipientSignedKey = createSignedKeys(account: recipientAccount, credentials: recipientCredentials)
            
            // Fake API response for keys upload and query
            self.createKeysUploadStub()
            self.createKeysQueryStub(credentials: recipientCredentials, device: recipientDevice)
            self.createKeysClaimStub(credentials: recipientCredentials, signedKey: recipientSignedKey)
            let txnId = "32"
            self.createSendToDeviceStub(txnId: txnId)
            
            let encryptionHandler = try EncryptionHandler.init(
                keychain: recipientKeychain,
                mxRestClient: recipientMXRestClient)
            
            // Test device creation
            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
            XCTAssertEqual(boolResult, true)
            
            // Test sending message
            let outcome = try await(encryptionHandler.handleSendMessage(recipients: [recipientUser], message: "Test Message", txnId: txnId))
            let successUsers = outcome.success.map {$0.userName}
            XCTAssertEqual(successUsers.contains(recipientCredentials.userId!), true)
            
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
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (encryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, senderMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Encrypt Message
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
            
            // Fake API response for sync then perform sync
            self.createSyncStub(wrappedMessage: wrappedSenderMessage, senderDevice: senderDevice)
            let syncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let decryptedMessage = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessage[EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId)], testMessageContent)
            XCTAssertEqual(encryptionHandler.oneTimeKeyCount, 1)
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testSimpleE2E() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Successfully sends and receives a message through Matrix")
        
        async {
            
            let (firstCredentials, _, firstHandler, _) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test1:matrix.org", password: "matrix_maps_test1")
            let (secondCredentials, _, secondHandler, secondMxRestClient) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test2:matrix.org", password: "matrix_maps_test2")
            
            // Send message from first device to second
            let recipient = EncryptedMessageRecipient.init(
                userName: secondCredentials.userId!,
                deviceName: secondCredentials.deviceId!)
            let (decryptedMessages, newE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: recipient,
                                         sendersHandler: firstHandler,
                                         recipientsMxRestClient: secondMxRestClient,
                                         recipientsHandler: secondHandler,
                                         messages: ["Test message"],
                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = newE2ESyncToken
            print(decryptedMessages)
            XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: firstCredentials.userId!, deviceName: firstCredentials.deviceId!)], "Test message")
            
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
            
            let (firstCredentials, _, firstHandler, _) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test1:matrix.org", password: "matrix_maps_test1")
            let (secondCredentials, _, secondHandler, secondMxRestClient) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test2:matrix.org", password: "matrix_maps_test2")
            
            // Send message from first device to second
            let recipient = EncryptedMessageRecipient.init(
                userName: secondCredentials.userId!,
                deviceName: secondCredentials.deviceId!)
            let (decryptedMessages, newE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: recipient,
                                         sendersHandler: firstHandler,
                                         recipientsMxRestClient: secondMxRestClient,
                                         recipientsHandler: secondHandler,
                                         messages: ["Test message", "Second test message"],
                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = newE2ESyncToken
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: firstCredentials.userId!, deviceName: firstCredentials.deviceId!)], "Second test message")
            
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
            
            let (firstCredentials, _, firstHandler, firstMXRestClient) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test1:matrix.org", password: "matrix_maps_test1")
            let firstRecipient = EncryptedMessageRecipient.init(
                userName: firstCredentials.userId!,
                deviceName: firstCredentials.deviceId!)
            let (secondCredentials, _, secondHandler, secondMxRestClient) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test2:matrix.org", password: "matrix_maps_test2")
            let secondRecipient = EncryptedMessageRecipient.init(
                userName: secondCredentials.userId!,
                deviceName: secondCredentials.deviceId!)
            
            // Send message from first device to second
            let (firstDecryptedMessages, newE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: secondRecipient,
                                                                         sendersHandler: firstHandler,
                                                                         recipientsMxRestClient: secondMxRestClient,
                                                                         recipientsHandler: secondHandler,
                                                                         messages: ["Test message"],
                                                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = newE2ESyncToken
            
            // Note only most recent message is outputted, as we only want the most recent location
            print(firstDecryptedMessages)
            XCTAssertEqual(firstDecryptedMessages[firstRecipient], "Test message")
            
            // Send message from second device to first
            let (secondDecryptedMessages, secondE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: firstRecipient,
                                                                         sendersHandler: secondHandler,
                                                                         recipientsMxRestClient: firstMXRestClient,
                                                                         recipientsHandler: firstHandler,
                                                                         messages: ["Another test message"],
                                                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = secondE2ESyncToken
            
            // Note only most recent message is outputted, as we only want the most recent location
            XCTAssertEqual(secondDecryptedMessages[secondRecipient], "Another test message")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testAlteredE2ESenderDevice() throws {
        
        let expectation = XCTestExpectation(description: "Successfully sends and receives a unidirectional message through Matrix after the sender has altered their device")
        
        async {
            
            var (firstCredentials, firstKeychain, firstHandler, _) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test1:matrix.org", password: "matrix_maps_test1")
            var firstRecipient = EncryptedMessageRecipient.init(
                userName: firstCredentials.userId!,
                deviceName: firstCredentials.deviceId!)
            let (secondCredentials, _, secondHandler, secondMxRestClient) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test2:matrix.org", password: "matrix_maps_test2")
            let secondRecipient = EncryptedMessageRecipient.init(
                userName: secondCredentials.userId!,
                deviceName: secondCredentials.deviceId!)
            
            // Send message from first device to second
            let (firstDecryptedMessages, newE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: secondRecipient,
                                                                         sendersHandler: firstHandler,
                                                                         recipientsMxRestClient: secondMxRestClient,
                                                                         recipientsHandler: secondHandler,
                                                                         messages: ["Test message"],
                                                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = newE2ESyncToken
            
            // Note only most recent message is outputted, as we only want the most recent location
            print(firstDecryptedMessages)
            XCTAssertEqual(firstDecryptedMessages[firstRecipient], "Test message")
            
            let initialFirstDeviceId = firstCredentials.deviceId
            
            // Alter senders device
            firstKeychain.delete(firstCredentials.userId!+"_encryptionAccount")
            firstKeychain.delete(firstCredentials.userId!+"_encryptionDevice")
            firstKeychain.delete(firstCredentials.userId!+"_encryptionSessions")
            firstKeychain.delete(firstCredentials.userId!+"_encryptionRecipientDevices")
            (firstCredentials, _, firstHandler, _) =
                try createE2ECredentialsKeychainEncryptionHandlerAndRestClient(userId: "@matrix_maps_test1:matrix.org", password: "matrix_maps_test1")
            firstRecipient = EncryptedMessageRecipient.init(
                userName: firstCredentials.userId!,
                deviceName: firstCredentials.deviceId!)
            
            XCTAssertNotEqual(initialFirstDeviceId, firstCredentials.deviceId)
            
            // Send another message
            let (repeatDecryptedMessages, secondE2ESyncToken) = try await(e2eSendMessageFromUserToUser(recipient: secondRecipient,
                                                                         sendersHandler: firstHandler,
                                                                         recipientsMxRestClient: secondMxRestClient,
                                                                         recipientsHandler: secondHandler,
                                                                         messages: ["Another test message"],
                                                                         lastSyncToken: self.lastE2ESyncToken))
            self.lastE2ESyncToken = secondE2ESyncToken
            
            XCTAssertEqual(repeatDecryptedMessages[firstRecipient], "Another test message")
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
        
    }
    
    func testFailPreKeyWithIncorrectIdentityKey() throws {
        
        let expectation = XCTestExpectation(description: "Decryption of prekey fails when incorrect key passed in wrapper")
        
        async {
            
            let testMessageContent = "Test message content"
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (encryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, senderMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Encrypt Message
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
            let mutatedWrappedSenderMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSenderMessage.algorithm,
                "ciphertext": wrappedSenderMessage.ciphertext,
                "senderKey": wrappedSenderMessage.senderKey.reversed(),
                "senderDevice": wrappedSenderMessage.senderDevice
            ])
            
            // Fake API response for sync then perform sync
            self.createSyncStub(wrappedMessage: mutatedWrappedSenderMessage, senderDevice: senderDevice)
            let syncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let decryptedMessage = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessage.keys.contains(EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)), false)
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
            
            let testMessageContent = "Test message content"
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (encryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, senderMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Encrypt Message
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
            
            // Fake API response for sync then perform sync
            self.createSyncStub(wrappedMessage: wrappedSenderMessage, senderDevice: senderDevice)
            let syncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let _ = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            // Set up return standard message
            let recipientSession = encryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            
            // Finally, start creating mutated standard message
            let _ = try senderSession.decryptMessage(standardReply)
            let secondStandardMessage = try senderSession.encryptMessageWithPayload(
                "A mutated reply",
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            
            XCTAssertEqual(secondStandardMessage.type, OLMMessageType.message)
            
            let wrappedSecondStandardMessageMessage = try encryptionLogic.wrapOLMMessage(secondStandardMessage, senderDevice: senderDevice)
            let mutatedWrappedSecondStandardMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSecondStandardMessageMessage.algorithm,
                "ciphertext": wrappedSecondStandardMessageMessage.ciphertext,
                "senderKey": wrappedSecondStandardMessageMessage.senderKey.reversed(),
                "senderDevice": wrappedSecondStandardMessageMessage.senderDevice
            ])
            // Fake API response for sync
            self.createSyncStub(wrappedMessage: mutatedWrappedSecondStandardMessage, senderDevice: senderDevice)
            let secondSyncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: secondSyncResponse))
            print(decryptedMessages)
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)), false)
            
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
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (encryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, senderMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Mutate Message
            let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice.jsonDictionary())!
            mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] = (mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] as! String).lowercased()
            
            // Encrypt Message
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: mutatedSenderDevice,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
            let mutatedWrappedSenderMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSenderMessage.algorithm,
                "ciphertext": wrappedSenderMessage.ciphertext,
                "senderKey": wrappedSenderMessage.senderKey.reversed(),
                "senderDevice": wrappedSenderMessage.senderDevice
            ])
            
            // Fake API response for sync then perform sync
            self.createSyncStub(wrappedMessage: mutatedWrappedSenderMessage, senderDevice: senderDevice)
            let syncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let decryptedMessage = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            XCTAssertEqual(decryptedMessage.keys.contains(EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)), false)
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
            
            let testMessageContent = "Test message content"
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (encryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, senderMXRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Encrypt Message
            let senderMessage = try senderSession.encryptMessageWithPayload(
                testMessageContent,
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            let encryptionLogic = EncryptionLogic()
            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
            
            // Fake API response for sync then perform sync
            self.createSyncStub(wrappedMessage: wrappedSenderMessage, senderDevice: senderDevice)
            let syncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            let _ = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
            
            // Set up return standard message
            let recipientSession = encryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            
            // Finally, start creating mutated standard message
            let _ = try senderSession.decryptMessage(standardReply)
            let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice.jsonDictionary())!
            mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] = (mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] as! String).lowercased()
            let secondStandardMessage = try senderSession.encryptMessageWithPayload(
                "A mutated reply",
                senderDevice: senderDevice,
                recipientDevice: encryptionHandler.device!)
            
            XCTAssertEqual(secondStandardMessage.type, OLMMessageType.message)
            
            let wrappedSecondStandardMessageMessage = try encryptionLogic.wrapOLMMessage(secondStandardMessage, senderDevice: senderDevice)
            let mutatedWrappedSecondStandardMessage = EncryptedMessageWrapper.init(dictionary: [
                "algorithm": wrappedSecondStandardMessageMessage.algorithm,
                "ciphertext": wrappedSecondStandardMessageMessage.ciphertext,
                "senderKey": wrappedSecondStandardMessageMessage.senderKey.reversed(),
                "senderDevice": wrappedSecondStandardMessageMessage.senderDevice
            ])
            // Fake API response for sync
            self.createSyncStub(wrappedMessage: mutatedWrappedSecondStandardMessage, senderDevice: senderDevice)
            let secondSyncResponse = try await(senderMXRestClient.syncPromise(
                fromToken: nil,
                serverTimeout: 5000,
                clientTimeout: 5000,
                setPresence: nil))
            
            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: secondSyncResponse))
            print(decryptedMessages)
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)), false)
            
            expectation.fulfill()
//            // Fake API response for keys upload
//            let uploadUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/keys/upload/testdevice"
//            let uploadMessageData: NSDictionary = [
//              "one_time_key_counts": [
//                "curve25519": 10,
//                "signed_curve25519": 20
//              ]
//            ]
//            self.stub(uri(uploadUriValue), json(uploadMessageData, status: 200))
//
//            let encryptionHandler = try EncryptionHandler.init(
//                keychain: self.keychain ,
//                mxRestClient: self.mxRestClient!)
//
//            // Test device creation
//            let boolResult = try await(encryptionHandler.createAndUploadDeviceKeys())
//            XCTAssertEqual(boolResult, true)
//
//            // Find recipient keys
//            let recipientIdentityKey = encryptionHandler.device?.identityKey
//            // An AAAAAQ OTK is always created in the first round
//            let recipientOTKey = ((encryptionHandler.account?.oneTimeKeys()["curve25519"]! as! [String: String])["AAAAAQ"])! as String
//
//            // Set up sender and encrypt message
//            let senderAccount = OLMAccount.init(newAccount: ())
//            let senderDevice = try senderAccount?.generateSignedDeviceKeys(credentials: self.secondCredentials!)
//            let senderSession = try OLMSession.init(
//                outboundSessionWith: senderAccount,
//                theirIdentityKey: recipientIdentityKey,
//                theirOneTimeKey: recipientOTKey)
//            let firstEncryptedMessage = try senderSession.encryptMessageWithPayload(
//                "Test",
//                senderDevice: senderDevice!,
//                recipientDevice: encryptionHandler.device!)
//            let encryptionLogic = EncryptionLogic()
//            let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(firstEncryptedMessage, senderDevice: senderDevice!)
//
//            // Fake API response for sync
//            let syncUriValue = "https://matrix-client.matrix.org/_matrix/client/r0/sync?timeout=5000"
//            let syncMessageData: NSDictionary = [
//                "account_data": [],
//                "next_batch": "s72595_4483_1934",
//                "presence": [],
//                "rooms": [
//                  "invite": [],
//                  "join": [],
//                  "leave":[]
//                ],
//                "to_device": [
//                    "events": [
//                        [
//                            "content": wrappedSenderMessage.nsDictionary,
//                            "sender": senderDevice!.userId!,
//                            "type": "matrixmaps.location"
//                        ]
//                    ]
//                ],
//                "device_one_time_keys_count": [
//                    "signed_curve25519": 1
//                ]
//            ]
//            self.stub(uri(syncUriValue), json(syncMessageData, status: 200))
//
//            let syncResponse = try await((self.mxRestClient?.syncPromise(
//                fromToken: nil,
//                serverTimeout: 5000,
//                clientTimeout: 5000,
//                setPresence: nil))!)
//
//            let _ = try await(encryptionHandler.handleSyncResponse(syncResponse: syncResponse))
//
//            // Set up return standard message
//            let recipientSession = encryptionHandler.getSession(user: senderDevice!.userId, device: senderDevice!.deviceId)!
//            let standardReply = try recipientSession.encryptMessage("A reply")
//
//            // Finally, start creating mutated standard message
//            let _ = try senderSession.decryptMessage(standardReply)
//            let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice!.jsonDictionary())
//            mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] = (mutatedSenderDevice!.keys["curve25519:\(mutatedSenderDevice!.deviceId!)"] as! String).lowercased()
//            let secondStandardMessage = try senderSession.encryptMessageWithPayload(
//                "A mutated reply",
//                senderDevice: mutatedSenderDevice!,
//                recipientDevice: encryptionHandler.device!)
//
//            XCTAssertEqual(secondStandardMessage.type, OLMMessageType.message)
//
//            let wrappedSecondStandardMessageMessage = try encryptionLogic.wrapOLMMessage(secondStandardMessage, senderDevice: senderDevice!)
//            // Fake API response for sync
//            let secondSyncMessageData: NSDictionary = [
//                "account_data": [],
//                "next_batch": "s72595_4483_1934",
//                "presence": [],
//                "rooms": [
//                  "invite": [],
//                  "join": [],
//                  "leave":[]
//                ],
//                "to_device": [
//                    "events": [
//                        [
//                            "content": wrappedSecondStandardMessageMessage.nsDictionary,
//                            "sender": senderDevice!.userId!,
//                            "type": "matrixmaps.location"
//                        ]
//                    ]
//                ],
//                "device_one_time_keys_count": [
//                    "signed_curve25519": 1
//                ]
//            ]
//            self.stub(uri(syncUriValue), json(secondSyncMessageData, status: 200))
//
//            let secondSyncResponse = try await((self.mxRestClient?.syncPromise(
//                fromToken: nil,
//                serverTimeout: 5000,
//                clientTimeout: 5000,
//                setPresence: nil))!)
//
//            let decryptedMessages = try await(encryptionHandler.handleSyncResponse(syncResponse: secondSyncResponse))
//            print(decryptedMessages)
//
//            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice!.userId!, deviceName: senderDevice!.deviceId!)), false)
//
//            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
        

}
