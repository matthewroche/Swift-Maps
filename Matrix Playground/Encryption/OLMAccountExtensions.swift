import Foundation
import OLMKit
import MatrixSDK
import Then

// Extending OLMAccount to make creation and signage of keys easier
public extension OLMAccount {
    
    /**
    Initialise the device properly with keys and signatures in correct structure.
    
    - parameters:
        - credentials: The instance f MXCredentials with which to sign the device..
    
    - returns: a `Promise` instance providing the properly formatted MXDeviceInfo on success.
    */
    func generateSignedDeviceKeys(credentials: MXCredentials) throws -> MXDeviceInfo {
        guard credentials.deviceId != nil else {throw EncryptionError.noCredentialsAvailable}
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
