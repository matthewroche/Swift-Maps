import Foundation
import OLMKit
import MatrixSDK
import Then

// Conveniance functions to properly wrap an OLMMessage for transmission
public class EncryptionLogic {
    
    public init() {}
    
    /**
    Create device keys and transmit them to the server.
    
    - parameters:
        - account: The OLMAccount for which we are creating new keys
        - mxRestClient: The MXRestClient instance to perfom networking request
    
    - returns: a `Promise` instance providing a tuple of  the properly formatted MXDeviceInfo and a dictionary defining the number of one time keys on success.
    */
    public func initialiseDeviceKeys(account: OLMAccount, mxRestClient: MXRestClient) throws -> Promise<(MXDeviceInfo, [String: NSNumber])> {
        async {
            guard mxRestClient.credentials != nil else {throw EncryptionError.noCredentialsAvailable}
            //Create device
            let device = try account.generateSignedDeviceKeys(credentials: mxRestClient.credentials)
            //Create signed oneTimeKeys
            let signedKeys = account.generateSignedOneTimeKeys(count: 10, credentials: mxRestClient.credentials)
            print("About to start keys upload")
            //Upload keys
            let response = try await(
                mxRestClient.uploadKeysPromise(device.jsonDictionary() as NSDictionary? as! [String: Any],
                                               oneTimeKeys: signedKeys,
                                               forDevice: mxRestClient.credentials?.deviceId))
            guard response.oneTimeKeyCounts != nil else {throw EncryptionError.keyUploadFailed}
            return(device, response.oneTimeKeyCounts)
        }
    }
    
    /**
    Create device keys and transmit them to the server.
    
    - parameters:
        - account: The OLMAccount for which we are creating new keys
        - mxRestClient: The MXRestClient instance to perfom networking request (TODO: This should be extracted to EncryptionLogic).
    
    - returns: a `Promise` instance providing a dictionary defining the number of one time keys on success.
    */
    public func uploadNewOneTimeKeys(account: OLMAccount, mxRestClient: MXRestClient, numberOfKeys: UInt) throws -> Promise<[String: NSNumber]> {
        async {
            guard mxRestClient.credentials != nil else {throw EncryptionError.noCredentialsAvailable}
            //Create signed oneTimeKeys
            let signedKeys = account.generateSignedOneTimeKeys(count: numberOfKeys, credentials: mxRestClient.credentials)
            print("About to start keys upload")
            //Upload keys
            let response = try await(mxRestClient.uploadKeysPromise([:], oneTimeKeys: signedKeys, forDevice: mxRestClient.credentials?.deviceId))
            return(response.oneTimeKeyCounts)
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
            "senderKey": senderDevice.identityKey,
            "senderDevice": senderDevice.deviceId
        ] as? [String: String] ?? [:]
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
