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

class Matrix_PlaygroundTests: XCTestCase {
    
    var lastE2ESyncToken: String?

    override func setUpWithError() throws {
    }

    override func tearDownWithError() throws {
        self.clearAllData()
    }
    
    func clearAllData() {
        let keychain = KeychainSwift()
        keychain.clear()
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
    
    func fakeMessageSend(senderSession: OLMSession, messageContent: String, senderDevice: MXDeviceInfo, recipientMXRestClient: MXRestClient, recipientEncryptionHandler: EncryptionHandler, mutateSenderKey: Bool = false, mutateSenderDevice: Bool = false) throws -> [EncryptedMessageRecipient: String] {
        
        // Mutate sender device for use if necessary
        let mutatedSenderDevice = MXDeviceInfo.init(fromJSON: senderDevice.jsonDictionary())!
        mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] = (mutatedSenderDevice.keys["curve25519:\(mutatedSenderDevice.deviceId!)"] as! String).lowercased()
        // Encrypt Message
        let senderMessage = try senderSession.encryptMessageWithPayload(
            messageContent,
            senderDevice: mutateSenderDevice ? mutatedSenderDevice : senderDevice,
            recipientDevice: recipientEncryptionHandler.device!)
        let encryptionLogic = EncryptionLogic()
        let wrappedSenderMessage = try encryptionLogic.wrapOLMMessage(senderMessage, senderDevice: senderDevice)
        let mutatedWrappedSenderMessage = EncryptedMessageWrapper.init(dictionary: [
            "algorithm": wrappedSenderMessage.algorithm,
            "ciphertext": wrappedSenderMessage.ciphertext,
            "senderKey": mutateSenderKey ? wrappedSenderMessage.senderKey.reversed(): wrappedSenderMessage.senderKey,
            "senderDevice": wrappedSenderMessage.senderDevice
        ])
        
        // Fake API response for sync then perform sync
        self.createSyncStub(wrappedMessage: mutatedWrappedSenderMessage, senderDevice: senderDevice)
        let syncResponse = try await(recipientMXRestClient.syncPromise(
            fromToken: nil,
            serverTimeout: 5000,
            clientTimeout: 5000,
            setPresence: nil))
        return try await(recipientEncryptionHandler.handleSyncResponse(syncResponse: syncResponse))
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
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            let decryptedMessage = try self.fakeMessageSend(senderSession: senderSession, messageContent: testMessageContent, senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler, mutateSenderKey: true)
            
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
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            let _ = try self.fakeMessageSend(senderSession: senderSession, messageContent: testMessageContent, senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
            
            // Set up return standard message
            let recipientSession = recipientEncryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            
            // Finally, start creating mutated standard message
            let _ = try senderSession.decryptMessage(standardReply)
            
            let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: "A mutated reply", senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler, mutateSenderKey: true)
            
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
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            let decryptedMessage = try self.fakeMessageSend(senderSession: senderSession, messageContent: testMessageContent, senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler, mutateSenderDevice: true)
            
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
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            let _ = try self.fakeMessageSend(senderSession: senderSession, messageContent: testMessageContent, senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
            
            // Set up return standard message
            let recipientSession = recipientEncryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            let _ = try senderSession.decryptMessage(standardReply)
            
            let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: testMessageContent, senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler, mutateSenderDevice: true)
            
            XCTAssertEqual(decryptedMessages.keys.contains(EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)), false)
            
            expectation.fulfill()
            
        }.onError { (error) in
            print(error)
        }
        
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testMultiplePrekeyFollowedByStandard() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of standard message succeeds after receiving multiple prekey messages")
        async {
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            for i in 1..<100 {
                let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: "testMessageContent_\(i)", senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
                XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)], "testMessageContent_\(i)")
                print("Decypted message \(i)")
            }
            
            // Set up return standard message
            let recipientSession = recipientEncryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
            let standardReply = try recipientSession.encryptMessage("A reply")
            let standardDecryptedReply = try senderSession.decryptMessage(standardReply)
            
            print(standardDecryptedReply)
            
            for i in 1..<10 {
                let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: "testMessageContent_\(i)", senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
                XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)], "testMessageContent_\(i)")
                print("Decypted standard message \(i)")
            }
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testSwitchingSendingDirection() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "Decryption of messages succeeds after switching directions of senders")
        async {
            
            // Set up recipient
            self.createKeysUploadStub()
            let (_, recipientKeychain, recipientMxRestClient) = createCredentialsKeychainAndRestClient(
                userId: "@testUser1:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (recipientEncryptionHandler, recipientIdentityKey, recipientOTKey) = try createEncryptionHandlerAndObtainKeys(keychain: recipientKeychain, mxRestClient: recipientMxRestClient)
            
            // Set up sender
            let (senderCredentials, _, _) = createCredentialsKeychainAndRestClient(
                userId: "@testUser2:matrix.org",
                accessToken: "fakeAccessToken",
                deviceName: "testDevice")
            let (_, senderDevice, senderSession) = try createEncryptionAccountDeviceAndSession(
                credentials: senderCredentials,
                recipientIdentityKey: recipientIdentityKey,
                recipientOTKey: recipientOTKey)
            
            // Unidirectional
            for i in 1..<10 {
                let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: "testMessageContent_\(i)", senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
                XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)], "testMessageContent_\(i)")
                print("Decypted message \(i)")
            }
            
            
            //Bidirectional
            for i in 1..<10 {
                // Set up return standard message
                let recipientSession = recipientEncryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
                let standardReply = try recipientSession.encryptMessage("A reply no: \(i)")
                let standardDecryptedReply = try senderSession.decryptMessage(standardReply)
                XCTAssertEqual(standardDecryptedReply, "A reply no: \(i)")
                let decryptedMessages = try self.fakeMessageSend(senderSession: senderSession, messageContent: "standardTestMessageContent_\(i)", senderDevice: senderDevice, recipientMXRestClient: recipientMxRestClient, recipientEncryptionHandler: recipientEncryptionHandler)
                XCTAssertEqual(decryptedMessages[EncryptedMessageRecipient(userName: senderDevice.userId!, deviceName: senderDevice.deviceId!)], "standardTestMessageContent_\(i)")
            }
            
            //Reversed Unidirectional
            for i in 1..<10 {
                // Set up return standard message
                let recipientSession = recipientEncryptionHandler.getSession(user: senderDevice.userId, device: senderDevice.deviceId)!
                let standardReply = try recipientSession.encryptMessage("A unidirectional reply no: \(i)")
                let unidirectionalDecryptedReply = try senderSession.decryptMessage(standardReply)
                XCTAssertEqual(unidirectionalDecryptedReply, "A unidirectional reply no: \(i)")
            }
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCanHandlePreKeyWithExistingSession() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "The app can handle receipt of a prekey message when a session already exists for the sending user")
        //This can happen when the remote user deleted the session, but we did not
        async {
            
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        wait(for: [expectation], timeout: 10.0)
    }
    
    func testCanWarnIfStandardMessageRecievedWithNoSession() throws {
        self.clearAllData()
        let expectation = XCTestExpectation(description: "The app warns the user if stadard messages continue to be received for a session that does not eixst locally")
        // This can happen when we deleted the session but the remote user did not
        async {
            
            
            expectation.fulfill()
        }.onError { (error) in
            print(error)
        }
        wait(for: [expectation], timeout: 10.0)
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
