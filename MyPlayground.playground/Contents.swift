import UIKit
import MatrixSDK
import Then
import OLMKit

let olmUtility = OLMUtility()
let encryptionLogic = EncryptionLogic()

async {
    //  Getting login session
    let homeServerUrl = URL(string: "http://matrix.org")!
    var mxRestClient = MXRestClient(homeServer: homeServerUrl, unrecognizedCertificateHandler: nil)


    //  Logging in matrix_maps_test1
    let credentials = try await(mxRestClient.loginPromise(
        type: MXLoginFlowType.password,
        username: "matrix_maps_test1",
        password: "matrix_maps_test1"))
    mxRestClient = MXRestClient(credentials: credentials, unrecognizedCertificateHandler: nil)
    //  Creating and upoading device keys
    let account = OLMAccount.init(newAccount: ())!
    let (device, _) = try await(encryptionLogic.initialiseDeviceKeys(account: account, mxRestClient: mxRestClient))
    print(device)
    
    // Logging in matrix_maps_test2
    var recipientMxRestClient = MXRestClient(homeServer: homeServerUrl, unrecognizedCertificateHandler: nil)
    let recipientCredentials = try await(recipientMxRestClient.loginPromise(
        type: MXLoginFlowType.password,
        username: "matrix_maps_test2",
        password: "matrix_maps_test2")
    )
    recipientMxRestClient = MXRestClient(credentials: recipientCredentials, unrecognizedCertificateHandler: nil)
    //  Creating and upoading device keys
    let recipientAccount = OLMAccount.init(newAccount: ())!
    let (recipientDevice, _) = try await(encryptionLogic.initialiseDeviceKeys(account: recipientAccount, mxRestClient: recipientMxRestClient))

//    // Obtaining keys for encryption
//    let downloadedKeys = try await(mxRestClient.downloadKeysPromise(forUsers: ["@matrix_maps_test2:matrix.org"]))
//    // Need to format key request correctly
//    let preKeysRequestDetails = MXUsersDevicesMap<NSString>()
//    for user in downloadedKeys.deviceKeys.userIds() {
//        for device in downloadedKeys.deviceKeys.deviceIds(forUser: user) {
//            preKeysRequestDetails.setObject("signed_curve25519", forUser: user, andDevice: device)
//        }
//    }
//    let downloadedPreKeys = try await(mxRestClient.claimOneTimeKeysPromise(for: preKeysRequestDetails))
//
//    // Find correct keys
//    let sendersRecipientDevice = downloadedKeys.deviceKeys.object(
//        forDevice: recipientCredentials.deviceId,
//        forUser: recipientCredentials.userId)!
//    let preKey = downloadedPreKeys.oneTimeKeys!.object(
//        forDevice: recipientCredentials.deviceId,
//        forUser: recipientCredentials.userId)!
//
//    // Check signatures on prekeys
//    let keyDeviceString = "ed25519:" + sendersRecipientDevice.deviceId!
//    print(signatures.object(forDevice: keyDeviceString, forUser: recipientCredentials.userId!))
//    try olmUtility.verifyEd25519Signature(
//        preKey.signatures.object(forDevice: keyDeviceString, forUser: recipientCredentials.userId!) as String,
//        key: sendersRecipientDevice.fingerprint,
//        message: MXCryptoTools.canonicalJSONData(forJSON: preKey.signalableJSONDictionary))
//
//
//    // Create session
//    let session = try OLMSession.init(
//        outboundSessionWith: account,
//        theirIdentityKey: sendersRecipientDevice.identityKey,
//        theirOneTimeKey: preKey.value)
//
//
//    // Encrypt messages - will have to encrypt for all devices in reality
//    let encryptedMessage = try session.encryptMessage("Test message")
//    print("First message type: \(encryptedMessage.type.rawValue)")
//    let secondEncryptedMessage = try session.encryptMessage("Another test message")
//    print("Second message type: \(secondEncryptedMessage.type.rawValue)")
//
//    //Decrypt message
//    let recipientSession = try OLMSession.init(inboundSessionWith: recipientAccount, oneTimeKeyMessage: encryptedMessage.ciphertext)
//    let decryptedMessage = try recipientSession.decryptMessage(encryptedMessage)
//    print("Decrypted: \(decryptedMessage)")
//    let secondDecryptedMessage = try recipientSession.decryptMessage(secondEncryptedMessage)
//    print("Decrypted: \(secondDecryptedMessage)")
//
//    //Encrypt reply
//    let encryptedReply = try recipientSession.encryptMessage("This is a reply")
//    print("Reply message type: \(encryptedReply.type.rawValue)")
//
//    //Decrypt reply
//    let decryptedReply = try session.decryptMessage(encryptedReply)
//    print("Decrypted: \(decryptedReply)")
//
//    //
//    // Demonstration of serialisation of sessions and devices for storage
//    //
//    //
//    // Since we will be putting this data into keychain encrypting with key (as OLM allows us to) is not important.
//    let key = credentials.accessToken?.data(using: String.Encoding.utf8)
//    let serialisedAccount = try account.serializeData(withKey: key)
//    let serialisedSession = try session.serializeData(withKey: key)
//    let serialisedSenderDevice = device.jsonString()
//    let serialisedSendersRecipientDevice = sendersRecipientDevice.jsonString()
//
//    let _ = try OLMAccount.init(serializedData: serialisedAccount, key: key)
//    let loadedSession = try OLMSession.init(serializedData: serialisedSession, key: key)
//    let loadedSenderDevice = try MXDeviceInfo.init(fromJSONString: serialisedSenderDevice!)
//    let loadedSendersRecipientDevice = try MXDeviceInfo.init(fromJSONString: serialisedSendersRecipientDevice!)
//
//    //
//    // Demonstration of end to end message transmission
//    //
//    //
//
//    let e2eMessage = try loadedSession.encryptMessageWithPayload(
//        "An e2e message",
//        senderDevice: loadedSenderDevice,
//        recipientDevice: loadedSendersRecipientDevice)
//    let anotherE2eMessage = try loadedSession.encryptMessageWithPayload(
//    "Another e2e message",
//    senderDevice: device,
//    recipientDevice: sendersRecipientDevice)
//
//    let wrappedE2eMessage = try encryptionLogic.wrapOLMMessage(e2eMessage, senderDevice: loadedSenderDevice)
//    let anotherWrappedE2eMessage = try encryptionLogic.wrapOLMMessage(anotherE2eMessage, senderDevice: loadedSenderDevice)
//
//    // Create message to send
//    let contentMap = MXUsersDevicesMap(map: ["@matrix_maps_test2:matrix.org": ["*": wrappedE2eMessage.nsDictionary]])
//    // Send message
//    try await(mxRestClient.sendDirectToDevicePromise(
//        eventType: "matrixmaps.location",
//        contentMap: contentMap!,
//        txnId: UUID().uuidString)
//    )
//    // Create message to send
//    let anotherContentMap = MXUsersDevicesMap(map: ["@matrix_maps_test2:matrix.org": ["*": anotherWrappedE2eMessage.nsDictionary]])
//    // Send message
//    try await(mxRestClient.sendDirectToDevicePromise(
//        eventType: "matrixmaps.location",
//        contentMap: anotherContentMap!,
//        txnId: UUID().uuidString)
//    )
//
//    //  Syncing to receive direct messages
//    let directSyncResponse = try await(
//        recipientMxRestClient.syncPromise(fromToken: nil, serverTimeout: 5000, clientTimeout: 5000, setPresence: nil))
//
//    // Demonstration of unwrapping string to final message
//    let recievedWrappedE2eMessage = EncryptedMessageWrapper.init(dictionary: directSyncResponse.toDevice!.events[0].content!)
//    let unwrappedE2eMessage = try encryptionLogic.unwrapOLMMessage(recievedWrappedE2eMessage)
//    let (decryptedE2eMessage, recipientsSenderDevice) = try recipientSession.decryptMessageWithPayload(
//        unwrappedE2eMessage,
//        recipientDevice: recipientDevice
//    )
//    print(decryptedE2eMessage)
//    print(recipientsSenderDevice)
//
//    // Unwrap second message using previous recipientsSenderDevice details
//    let secondRecievedWrappedE2eMessage = EncryptedMessageWrapper.init(dictionary: directSyncResponse.toDevice!.events[1].content!)
//    let secondUnwrappedE2eMessage = try encryptionLogic.unwrapOLMMessage(secondRecievedWrappedE2eMessage)
//    let secondDecryptedE2eMessage = try recipientSession.decryptMessageWithPayload(
//        secondUnwrappedE2eMessage,
//        recipientDevice: recipientDevice,
//        senderDevice: recipientsSenderDevice
//    )
//    print(secondDecryptedE2eMessage)
    
////  Proving can obtain all messages sent in order
//
    // Create message to send
    for i in 0..<150 {
        let dictionary: NSDictionary = [
            "messageNumber" : i
        ]
        let contentMap = MXUsersDevicesMap(map: ["@matrix_maps_test2:matrix.org": [recipientmxRestClient.credentials?.deviceId!: dictionary]])
        // Send message
        try await(mxRestClient.sendDirectToDevicePromise(
            eventType: "matrixmaps.location",
            contentMap: contentMap!,
            txnId: UUID().uuidString)
        )
    }

//  Syncing to receive direct message
    var directSyncResponse = try await(
        recipientMxRestClient.syncPromise(fromToken: nil, serverTimeout: 5000, clientTimeout: 5000, setPresence: nil))
    directSyncResponse.toDevice.events.sort { (lhs, rhs) -> Bool in
        lhs.age > rhs.age
    }
    print("Number of messages received: \(directSyncResponse.toDevice?.events.count ?? 0)")
    print("Order of messages:")
    for event in directSyncResponse.toDevice.events {
        print(event.content["messageNumber"]! as! Int)
    }
    
    // Create more message to send
    for i in 150..<200 {
        let dictionary: NSDictionary = [
            "messageNumber" : i
        ]
        let contentMap = MXUsersDevicesMap(map: ["@matrix_maps_test2:matrix.org": [recipientmxRestClient.credentials?.deviceId!: dictionary]])
        // Send message
        try await(mxRestClient.sendDirectToDevicePromise(
            eventType: "matrixmaps.location",
            contentMap: contentMap!,
            txnId: UUID().uuidString)
        )
    }
    
    //Syncing to receive direct message
    directSyncResponse = try await(
        recipientMxRestClient.syncPromise(
            fromToken: directSyncResponse.nextBatch,
            serverTimeout: 5000,
            clientTimeout: 5000,
            setPresence: nil))
    directSyncResponse.toDevice.events.sort { (lhs, rhs) -> Bool in
        lhs.age > rhs.age
    }
    print("Number of messages received: \(directSyncResponse.toDevice?.events.count ?? 0)")
    print("Order of messages:")
    for event in directSyncResponse.toDevice.events {
        print(event.content["messageNumber"]! as! Int)
    }
    // Messages are received in order if fromToken is used, but are limited to maximum 100
    // Therefor sync with fromToken, and sync again if exactly 100 received.
    
    
    
    
    // Clear created devices
    let authSession = try await(mxRestClient.getSessionPromise(toDeleteDevice: credentials.deviceId!))
    let authDetails = [
        "session": authSession.session!,
        "type": "m.login.password",
        "user": credentials.userId!,
        "identifier": [
          "type": "m.id.user",
          "user": credentials.userId!
        ],
        "password": "matrix_maps_test1"
    ] as [String : Any]
    try await(mxRestClient.deleteDevicePromise(credentials.deviceId!, authParameters: authDetails))
    let recipientAuthSession = try await(recipientMxRestClient.getSessionPromise(toDeleteDevice: recipientCredentials.deviceId!))
    let recipientAuthDetails = [
        "session": recipientAuthSession.session!,
        "type": "m.login.password",
        "user": recipientCredentials.userId!,
        "identifier": [
          "type": "m.id.user",
          "user": recipientCredentials.userId!
        ],
        "password": "matrix_maps_test2"
    ] as [String : Any]
    try await(recipientMxRestClient.deleteDevicePromise(recipientCredentials.deviceId!, authParameters: recipientAuthDetails))
    
    

}.onError { e in
    print("An error occured")
    print(e)
}

/// A wrapper containing the OLMMessage to be transmitted with accompanying unencrypted data
public class EncryptedMessageWrapper: Codable {
    public let algorithm: String
    public let ciphertext: String
    public let senderKey: String
    
    public init(dictionary: [String: Any]) {
        self.algorithm = dictionary["algorithm"] as? String ?? ""
        self.ciphertext = dictionary["ciphertext"] as? String ?? ""
        self.senderKey = dictionary["senderKey"] as? String ?? ""
    }
    
    var dictionary: [String: Any] {
        return ["algorithm": algorithm,
                "ciphertext": ciphertext,
                "senderKey": senderKey]
    }
    public var nsDictionary: NSDictionary {
        return dictionary as NSDictionary
    }
}

// Conveniance functions to properly wrap an OLMMessage for transmission
public class EncryptionLogic {
    
    public init() {}
    
    /**
    Create device keys and transmit them to the server.
    
    - parameters:
        - mxRestClient: The MXRestClient instance to perfom networking request (TODO: This should be extracted to EncryptionLogic).
    
    - returns: a `Promise` instance providing a tuple of  the properly formatted MXDeviceInfo and a dictionary defining the number of one time keys on success.
    */
    public func initialiseDeviceKeys(account: OLMAccount, mxRestClient: MXRestClient) throws -> Promise<(MXDeviceInfo, [String: NSNumber])> {
        async {
            //Create device
            let device = try account.generateSignedDeviceKeys(credentials: mxRestClient.credentials?)
            //Create signed oneTimeKeys
            let signedKeys = account.generateSignedOneTimeKeys(count: 10, credentials: mxRestClient.credentials?)
            //Upload keys
            let response = try await(
                mxRestClient.uploadKeysPromise(device.jsonDictionary() as NSDictionary? as! [String: Any],
                                               oneTimeKeys: signedKeys,
                                               forDevice: mxRestClient.credentials?.deviceId))
            return(device, response.oneTimeKeyCounts)
        }
    }
    
    /**
    Wrap an OLM message with the algorithm and sender key.
    
    - parameters:
        - olmMessage: The message to wrap
    
    - returns: EncryptedPayloadWrapper instance containing the wrapped key
    */
    public func wrapOLMMessage(_ olmMessage: OLMMessage, senderDevice: MXDeviceInfo) throws -> EncryptedMessageWrapper {
        let codableOLMMessage = CodableOLMMessage(from: olmMessage)
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        let encryptedPayloadData = try encoder.encode(codableOLMMessage)
        let encryptedPayloadString = String.init(data: encryptedPayloadData, encoding:String.Encoding.utf8)!
        let wrapperObject = [
            "algorithm": "m.olm.v1.curve25519-aes-sha2",
            "ciphertext": encryptedPayloadString,
            "senderKey": senderDevice.identityKey
            ] as [String: String]
        return EncryptedMessageWrapper(dictionary: wrapperObject)
    }
    
    
    /**
    Unwrap a wrapped OLM message..
    
    - parameters:
        - wrappedMessage: The message to unwrap
    
    - returns: OLMMessage instance containing the unwrapped message
    */
    public func unwrapOLMMessage(_ wrappedMessage: EncryptedMessageWrapper) throws -> OLMMessage {
        // Create wrapper object from string
        let messageData = wrappedMessage.ciphertext.data(using: String.Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(CodableOLMMessage.self, from: messageData)
    }


}


// Extend MXDeviceInfo to enable initialisation from a JSON String
public extension MXDeviceInfo {

    /**
    Initialise MXDeviceInfo with a JSON string
    
    - parameters:
        - fromJSONString: The JSON string with which to create the instance
    
    - returns: MXDeviceInfo instance
    */
    convenience init(fromJSONString JSONString: String) throws {
        let deviceJSON = try JSONSerialization.jsonObject(with: JSONString.data(using: String.Encoding.utf8)!) as! [AnyHashable: Any]
        self.init(fromJSON: deviceJSON)
    }

}

//Extending MXRestClient to enable use of promises
public extension MXRestClient {
    
    
    // MARK: - Login Operation

    /**
    Get the list of login flows supported by the home server.
    
    - parameters:
        - completion: A block object called when the operation completes.
    
    - returns: a `Promise` instance providing the server response as an MXAuthenticationSession instance on success.
    */
    func getLoginSessionPromise() -> Promise<MXAuthenticationSession> {
        return Promise { resolve, reject in
            self.getLoginSession() { response in
                switch response {
                case .success(let session):
                    resolve(session)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Log a user in.
    
    This method manages the full flow for simple login types and returns the credentials of the logged matrix user.
    
    - parameters:
        - type: the login type. Only `MXLoginFlowType.password` (m.login.password) is supported.
        - username: the user id (ex: "@bob:matrix.org") or the user id localpart (ex: "bob") of the user to authenticate.
        - password: the user's password.
    
    - returns: a `Promise` instance providing credentials for this user on success
    */
    func loginPromise(type: MXLoginFlowType = .password, username: String, password: String) -> Promise<MXCredentials> {
        return Promise { resolve, reject in
            self.login(type: type, username: username, password: password) { response in
                switch response {
                case .success(let session):
                    resolve(session)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Reset the account password.
    
    - parameters:
        - parameters: a set of parameters containing a threepid credentials and the new password.
    
    - returns: a `Promise` instance providing a `DarwinBoolean` indicating whether the operation was successful..
    */
    func resetPasswordPromise(parameters: [String: Any]) -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.resetPassword(parameters: parameters) { response in
                switch response {
                case .success:
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Replace the account password.
    
    - parameters:
        - old: the current password to update.
        - new: the new password.
    
    - returns: a `Promise` instance providing a `DarwinBoolean` indicating whether the operation was successful.
    */
    func changePasswordPromise(from old: String, to new: String) -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.changePassword(from: old, to: new) { response in
                switch response {
                case .success:
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    

    /**
    Invalidate the access token, so that it can no longer be used for authorization.
    
    - parameters:
        - completion: A block object called when the operation completes.
    
    - returns: a `Promise` instance providing a `DarwinBoolean` indicating whether the operation was successful..
    */
    func logoutPromise() -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.logout() { response in
                switch response {
                case .success:
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    // MARK: - Room operations
    
    func getSessionPromise(toDeleteDevice: String) -> Promise<MXAuthenticationSession> {
        return Promise { resolve, reject in
            self.getSession(toDeleteDevice: toDeleteDevice) { response in
                switch response {
                case .success (let authSession):
                    resolve(authSession)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    func deleteDevicePromise(_ deviceId: String, authParameters: [String: Any]) -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.deleteDevice(deviceId, authParameters: authParameters) { response in
                switch response {
                case .success:
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
            
        }
    }
    
    
    // MARK: - Room operations
    
    
    /**
    Send a text message to a room
    
    - parameters:
       - roomId: the id of the room.
       - text: the text to send.
    
    - returns: a `Promise` instance providing the event id of the event generated on the home server on success.
    */
    func sendTextMessagePromise(toRoom roomId: String, text: String) -> Promise<String> {
        return Promise { resolve, reject in
            self.sendTextMessage(toRoom: roomId, text: text) { response in
                switch response {
                case .success (let eventId):
                    resolve(eventId)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Join a room, optionally where the user has been invited by a 3PID invitation.
    
    - parameters:
       - roomIdOrAlias: The id or an alias of the room to join.
       - viaServers The server names to try and join through in addition to those that are automatically chosen.
       - thirdPartySigned: The signed data obtained by the validation of the 3PID invitation, if 3PID validation is used. The validation is made by `self.signUrl()`.
    
    - returns: a `Promise` instance providing the room id on success..
    */
    func joinRoomPromise(_ roomIdOrAlias: String, viaServers: [String]? = nil, withThirdPartySigned dictionary: [String: Any]? = nil) -> Promise<String> {
        return Promise { resolve, reject in
            self.joinRoom(roomIdOrAlias, viaServers: viaServers, withThirdPartySigned: dictionary) { response in
                switch response {
                case .success (let eventId):
                    resolve(eventId)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Leave a room.
    
    - parameters:
       - roomId: the id of the room to leave.
    
    - returns: a `Promise` instace providing a `DarwinBoolean` indicating whether the operation was successful.
    */
    func leaveRoomPromise(_ roomIdOrAlias: String) -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.leaveRoom(roomIdOrAlias) { response in
                switch response {
                case .success:
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Create a room.
    
    - parameters:
       - parameters: The parameters for room creation.
    
    - returns: a `Promise` instance providing an `MXCreateRoomResponse` object on success.
    */
    func createRoomPromise(parameters: MXRoomCreationParameters) -> Promise<MXCreateRoomResponse> {
        return Promise { resolve, reject in
            self.createRoom(parameters: parameters) { response in
                switch response {
                case .success (let roomCreationParameters):
                    resolve(roomCreationParameters)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Get a list of messages for this room.
    
    - parameters:
       - roomId: the id of the room.
       - from: the token to start getting results from.
       - direction: `MXTimelineDirectionForwards` or `MXTimelineDirectionBackwards`
       - limit: (optional, use -1 to not defined this value) the maximum nuber of messages to return.
       - filter: to filter returned events with.
    
    - returns: a `Promise` instance providing an `MXPaginationResponse` object on success.
    */
    func messagesPromise(forRoom roomId: String, from: String, direction: MXTimelineDirection, limit: UInt?, filter: MXRoomEventFilter) -> Promise<MXPaginationResponse> {
        return Promise { resolve, reject in
            self.messages(forRoom: roomId, from: from, direction: direction, limit: limit, filter: filter) { response in
                switch response {
                case .success (let paginationResponse):
                    resolve(paginationResponse)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    // MARK: - Direct To Device
    
    /**
     Send an event to a specific list of devices
     
     - paramaeters:
        - eventType: the type of event to send
        - contentMap: content to send. Map from user_id to device_id to content dictionary in form [String: [String: NSDictionary}}.
     
     - returns: a `Promise` instance returning a boolean value if the operation was successful.
     */
    func sendDirectToDevicePromise(eventType: String, contentMap: MXUsersDevicesMap<NSDictionary>, txnId: String) -> Promise<DarwinBoolean> {
        return Promise { resolve, reject in
            self.sendDirectToDevice(eventType: eventType, contentMap: contentMap, txnId: txnId) { response in
                switch response {
                case .success():
                    resolve(true)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    // MARK: - Sync
    
    
    /**
    Synchronise the client's state and receive new messages.
    
    Synchronise the client's state with the latest state on the server.
    Client's use this API when they first log in to get an initial snapshot
    of the state on the server, and then continue to call this API to get
    incremental deltas to the state, and to receive new messages.
    
    - parameters:
       - token: the token to stream from (nil in case of initial sync).
       - serverTimeout: the maximum time in ms to wait for an event.
       - clientTimeout: the maximum time in ms the SDK must wait for the server response.
       - presence:  the optional parameter which controls whether the client is automatically marked as online by polling this API. If this parameter is omitted then the client is automatically marked as online when it uses this API. Otherwise if the parameter is set to "offline" then the client is not marked as being online when it uses this API.
       - filterId: the ID of a filter created using the filter API (optinal).
    
    - returns: a `Promise` instance providing the `MXSyncResponse` on success.
    */
    func syncPromise(fromToken token: String?, serverTimeout: UInt, clientTimeout: UInt, setPresence presence: String?, filterId: String? = nil) -> Promise<MXSyncResponse> {
        return Promise { resolve, reject in
            self.sync(fromToken: token, serverTimeout: serverTimeout, clientTimeout: clientTimeout, setPresence: presence, filterId: filterId) { response in
                switch response {
                case .success (let syncResponse):
                    resolve(syncResponse)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    // MARK: - Crypto
    
    /**
     Upload device and/or one-time keys.
     
     - parameters:
        - deviceKeys: the device keys to send.
        - oneTimeKeys: the one-time keys to send.
        - deviceId: the explicit device_id to use for upload (pass `nil` to use the same as that used during auth).
     
     - returns: a `Promise` instance providing information about the keys on success.
     */
    func uploadKeysPromise(_ deviceKeys: [String: Any], oneTimeKeys: [String: Any], forDevice deviceId: String? = nil) -> Promise<MXKeysUploadResponse> {
        return Promise { resolve, reject in
            self.uploadKeys(deviceKeys, oneTimeKeys: oneTimeKeys, forDevice: deviceId) { response in
                switch response {
                case .success (let keysUploadResponse):
                    resolve(keysUploadResponse)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    /**
    Download device keys.
    
    - parameters:
       - userIds: list of users to get keys for.
       - token: sync token to pass in the query request, to help the HS give the most recent results. It can be nil.
    
    - returns: a `Promise` instance resolving to an MXKeysQueryResponse providing information about the keys on success.
    */
    func downloadKeysPromise(forUsers userIds: [String], token: String? = nil) -> Promise<MXKeysQueryResponse> {
        return Promise { resolve, reject in
            self.downloadKeys(forUsers: userIds, token: token) { response in
                switch response {
                case .success (let keysQueryResponse):
                    resolve(keysQueryResponse)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    /**
    Claim one-time keys.
    
    - parameters:
       - usersDevices: a list of users, devices and key types to retrieve keys for.
       - response: Provides information about the keys on success.
    
    - returns: a `Promise` instance resolving to an MXKeysClaimResponse providing information about the keys on success
    */
    func claimOneTimeKeysPromise(for usersDevices: MXUsersDevicesMap<NSString>) -> Promise<MXKeysClaimResponse> {
        return Promise { resolve, reject in
            self.claimOneTimeKeys(for: usersDevices) { response in
                switch response {
                case .success (let keysClaimResponse):
                    resolve(keysClaimResponse)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
}

// Extending OLMAccount to make creation and signage of keys easier
public extension OLMAccount {
    
    /**
    Initialise the device properly with keys and signatures in correct structure.
    
    - parameters:
        - credentials: The instance f MXCredentials with which to sign the device..
    
    - returns: a `Promise` instance providing the properly formatted MXDeviceInfo on success.
    */
    func generateSignedDeviceKeys(credentials: MXCredentials) throws -> MXDeviceInfo {
        let identityKeys = self.identityKeys()
        //Create device
        let device = MXDeviceInfo.init(deviceId: credentials.deviceId)!
        device.userId = credentials.userId
        device.algorithms = ["ed25519", "curve25519"]
        device.keys = [:]
        for key in Array(identityKeys!.keys) {
            let keyName = key as! String + ":" + credentials.deviceId!
            device.keys[keyName] = identityKeys![key]
        }
        //Sign device
        device.signatures = self.signDevice(device: device, credentials: credentials)
        return device
    }

    /**
    Sign an MXDeviceInfo instance
    
    - parameters:
        - device: The MXDeviceInfo instance to sign
        - credentials: The MXCredentials with which to perform the signing
    
    - returns: a dictionary containing the signed keys
    */
    private func signDevice(device: MXDeviceInfo, credentials: MXCredentials) -> [String:Dictionary<String, String>] {
        
        let signableJSON = device.signalableJSONDictionary
        let signature = self.signMessage(MXCryptoTools.canonicalJSONData(forJSON: signableJSON!))
        var signedSignatures = [String:Dictionary<String, String>]()
        let signatureName = "ed25519:"+credentials.deviceId!
        signedSignatures[credentials.userId!] = Dictionary<String, String>()
        signedSignatures[credentials.userId!]![signatureName] = signature
        
        return signedSignatures
        
    }
    /**
    Generates properly signed one-time keys using MXCredentials
    
    - parameters:
        - count: The number of one time keys to produce
        - credentials: The MXCredentials instance with which to sign the keys
    
    - returns: a Dictionary containing the signed keys.
    */
    func generateSignedOneTimeKeys(count: UInt, credentials: MXCredentials) -> [String:Dictionary<String, Any>] {
        self.generateOneTimeKeys(count)
        let oneTimeKeys = self.oneTimeKeys()
        let oneTimeKeysDictionary = oneTimeKeys!["curve25519"] as! Dictionary<String, String>
        var signedKeys = [String:Dictionary<String, Any>]()
        for key in Array(oneTimeKeysDictionary.keys) {
            let signedKeyName = "signed_curve25519:" + key
            signedKeys[signedKeyName] = Dictionary<String, String>()
            signedKeys[signedKeyName]!["key"] = oneTimeKeysDictionary[key]
            var signature = Dictionary<String, Dictionary<String, String>>()
            signature[credentials.userId!] = Dictionary<String, String>()
            let signatureName = "ed25519:"+credentials.deviceId!
            signature[credentials.userId!]![signatureName] = self.signMessage(MXCryptoTools.canonicalJSONData(forJSON: signedKeys[signedKeyName]!))
            signedKeys[signedKeyName]!["signatures"] = signature
        }
        return signedKeys
    }

}

// The payload of data that must be contained within an OLM Message
public class EncryptedPayload: Codable {
    public let content: String
    public let sender: String
    public let senderDevice: String
    public let keys: Dictionary<String, String>
    public let recipient: String
    public let recipientKeys: Dictionary<String, String>
    
    init(_ dictionary: [String: Any]) {
        self.content = dictionary["content"] as? String ?? ""
        self.sender = dictionary["sender"] as? String ?? ""
        self.senderDevice = dictionary["senderDevice"] as? String ?? ""
        self.keys = dictionary["keys"] as? Dictionary<String, String> ?? [:]
        self.recipient = dictionary["recipient"] as? String ?? ""
        self.recipientKeys = dictionary["recipientKeys"] as? Dictionary<String, String> ?? [:]
    }
}


// Extends an OLM Message to become codable
public class CodableOLMMessage: OLMMessage, Codable {
    
    enum CodingKeys: CodingKey {
        case ciphertext, type
    }
    
    public init(from olmMessage: OLMMessage) {
        super.init(ciphertext: olmMessage.ciphertext, type: olmMessage.type)!
    }

    public required init(from decoder: Decoder) throws {

        let container = try decoder.container(keyedBy: CodingKeys.self)
        let ciphertext = try container.decode(String.self, forKey: .ciphertext)
        let type = try container.decode(Int.self, forKey: .type)
        switch type {
        case 1:
            super.init(ciphertext: ciphertext, type: .message)!
        default:
            super.init(ciphertext: ciphertext, type: .preKey)!
        }
        
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(ciphertext, forKey: .ciphertext)
        try container.encode(type.rawValue, forKey: .type)
    }
}

public extension OLMSession {
    
    // MARK: - Encryption
    
    /**
    Encrypts a defined message with the required accompanying data
    
    - parameters:
        - content: The message to encrypt
        - senderDevice: An instance of MXDevice info representing the sender's device
        - recipientDevice: An instance of MXDeviceInfo representing the recipient's device
    
    - returns: OLMMessage instance containing the encrypted
    */
    func encryptMessageWithPayload(_ content: String, senderDevice: MXDeviceInfo, recipientDevice: MXDeviceInfo) throws -> OLMMessage {
        let payloadString = try self.createPayloadForEncryption(
            content,
            senderDevice: senderDevice,
            recipientDevice: recipientDevice)
        return try self.encryptMessage(payloadString)
    }
    
    /**
    PRIVATE: Creates the payload of data to be encrypted
    
    - parameters:
        - content: The message to encrypt
        - senderDevice: An instance of MXDevice info representing the sender's device
        - recipientDevice: An instance of MXDeviceInfo representing the recipient's device
    
    - returns: A JSON string representing the payload of data from transimssion
    */
    private func createPayloadForEncryption(_ content: String, senderDevice: MXDeviceInfo, recipientDevice: MXDeviceInfo) throws ->
        String {
            let payloadObject = [
                "sender": senderDevice.userId!,
                "senderDevice": senderDevice.deviceId!,
                "keys": [
                    "ed25519": senderDevice.identityKey
                ],
                "recipient": recipientDevice.userId ?? "null",
                "recipientKeys": [
                    "ed25519": recipientDevice.identityKey
                ],
                "content": content
            ] as [String: Any]
            let finalPayloadObject = EncryptedPayload(payloadObject)
            let encoder = JSONEncoder()
            encoder.keyEncodingStrategy = .convertToSnakeCase
            let payloadData = try encoder.encode(finalPayloadObject)
            return String.init(data: payloadData, encoding:String.Encoding.utf8)!
    }
    
    // MARK: - Decryption
    
    /**
    Decrypts an OLM message which is known to contain a payload of data as defined in EncryptedPayload
    
    - parameters:
        - encryptedMessage: The message to encrypt
        - recipientDevice: An instance of MXDevice info representing the recipient's device
    
    - returns: A tuple containing a string representing the decrypted message content and an instance of MXDeviceInfo representing the sender's device.
    */
    func decryptMessageWithPayload(_ encryptedMessage: OLMMessage, recipientDevice: MXDeviceInfo) throws -> (String, MXDeviceInfo) {
        
        let payloadString = try self.decryptMessage(encryptedMessage)
        let payloadData = payloadString.data(using: String.Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payloadObject = try decoder.decode(EncryptedPayload.self, from: payloadData)
        
        // Validation
        guard payloadObject.recipient == recipientDevice.userId else {throw OLMSessionError.messageFailedVerification}
        guard payloadObject.recipientKeys["ed25519"] == recipientDevice.identityKey else {throw OLMSessionError.messageFailedVerification}
        
        let senderDevice = MXDeviceInfo.init(deviceId: payloadObject.senderDevice)!
        senderDevice.userId = payloadObject.sender
        senderDevice.keys = [:]
        let identityKeyName = "curve25519:" + payloadObject.senderDevice
        senderDevice.keys[identityKeyName] = payloadObject.keys["ed25519"]
        
        return (payloadObject.content, senderDevice)
        
    }
    
    
    /**
    Decrypts and validates an OLM message which is known to contain a payload of data as defined in EncryptedPayload
    
    - parameters:
        - encryptedMessage: The message to encrypt
        - recipientDevice: An instance of MXDevice info representing the recipient's device
        - senderDevice: An instance of MXDeviceInfo representing the senders's device (optional)
    
    - returns: A string representing the decrypted message content
    */
    func decryptMessageWithPayload(_ encryptedMessage: OLMMessage, recipientDevice: MXDeviceInfo, senderDevice: MXDeviceInfo) throws -> String {
        
        let payloadString = try self.decryptMessage(encryptedMessage)
        let payloadData = payloadString.data(using: String.Encoding.utf8)!
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let payloadObject = try decoder.decode(EncryptedPayload.self, from: payloadData)
        
        // Validation
        guard payloadObject.sender == senderDevice.userId else {throw OLMSessionError.messageFailedVerification}
        guard payloadObject.senderDevice == senderDevice.deviceId else {throw OLMSessionError.messageFailedVerification}
        guard payloadObject.keys["ed25519"] == senderDevice.identityKey else {throw OLMSessionError.messageFailedVerification}
        guard payloadObject.recipient == recipientDevice.userId else {throw OLMSessionError.messageFailedVerification}
        guard payloadObject.recipientKeys["ed25519"] == recipientDevice.identityKey else {throw OLMSessionError.messageFailedVerification}
        
        return payloadObject.content
        
    }

}

enum OLMSessionError: Error {
    case messageFailedVerification
}

