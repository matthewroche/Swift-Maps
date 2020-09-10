import Foundation


/// A wrapper containing the OLMMessage to be transmitted with accompanying unencrypted data
/// Can be created from a dictionary, and exported as a ditionary or NSDictionary
public class EncryptedMessageWrapper: Codable {
    public let algorithm: String
    public let ciphertext: String
    public let senderKey: String
    public let senderDevice: String
    
    /// init
    /// Initialise from a dictionary
    /// - Parameter dictionary: The dictionary from which we are creating the EncryptedMessageWrapper
    public init(dictionary: [String: Any]) {
        self.algorithm = dictionary["algorithm"] as? String ?? ""
        self.ciphertext = dictionary["ciphertext"] as? String ?? ""
        self.senderKey = dictionary["senderKey"] as? String ?? ""
        self.senderDevice = dictionary["senderDevice"] as? String ?? ""
    }
    
    /// Convert the EncryptedMessageWrapper to a dictionary
    var dictionary: [String: Any] {
        return ["algorithm": algorithm,
                "ciphertext": ciphertext,
                "senderKey": senderKey,
                "senderDevice": senderDevice]
    }
    /// Convert the EncryptedMessageWrapper to an NSDictionary.
    public var nsDictionary: NSDictionary {
        return dictionary as NSDictionary
    }
}



// A class defining a recipient and their device
public class EncryptedMessageRecipient: Equatable, Hashable {
    
    public let userName: String
    public let deviceName: String
    var combinedName: String {
        return "\(self.userName):\(self.deviceName)"
    }
    
    /// init
    /// Initialise from strings
    /// - Parameters:
    ///   - userName: The username fo the recipient
    ///   - deviceName: The deviceName of the recipient
    public init(userName: String, deviceName: String) {
        self.userName = userName
        self.deviceName = deviceName
    }
    
    
    /// init
    /// Initialise from a combined name
    /// - Parameter combinedName: The combined name to initialise from
    public init(combinedName: String) throws {
        let components = combinedName.components(separatedBy: ":")
        guard components.count == 2 else {throw EncryptionError.invalidCombinedName}
        self.userName = components[0]
        self.deviceName = components[1]
    }
    
    // Conforming to Equatable
    public static func == (lhs: EncryptedMessageRecipient, rhs: EncryptedMessageRecipient) -> Bool {
        return lhs.combinedName == rhs.combinedName
    }
    
    // Conforming to hashable
    public func hash(into hasher: inout Hasher) {
        hasher.combine(userName)
        hasher.combine(deviceName)
    }
}

// A class representing the data returned after decrypting multiple messages contained in a sync response.
public class EncryptedSentMessageOutcome {
    public var success: [EncryptedMessageRecipient] = []
    public var failure: [(EncryptedMessageRecipient, Error)] = []
}


