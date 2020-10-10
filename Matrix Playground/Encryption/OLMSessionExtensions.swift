import Foundation

import Foundation
import OLMKit
import MatrixSDK

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
