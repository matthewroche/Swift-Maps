import Foundation



/// A wrapper containing the OLMMessage to be transmitted with accompanying unencrypted data
public class EncryptedMessageWrapper: Codable {
    public let algorithm: String
    public let ciphertext: String
    public let senderKey: String
    public let senderDevice: String
    
    public init(dictionary: [String: Any]) {
        self.algorithm = dictionary["algorithm"] as? String ?? ""
        self.ciphertext = dictionary["ciphertext"] as? String ?? ""
        self.senderKey = dictionary["senderKey"] as? String ?? ""
        self.senderDevice = dictionary["senderDevice"] as? String ?? ""
    }
    
    var dictionary: [String: Any] {
        return ["algorithm": algorithm,
                "ciphertext": ciphertext,
                "senderKey": senderKey,
                "senderDevice": senderDevice]
    }
    public var nsDictionary: NSDictionary {
        return dictionary as NSDictionary
    }
}

// A class defining a recipient and their device
public class EncryptedMessageRecipient: Equatable, Hashable {
    
    public static func == (lhs: EncryptedMessageRecipient, rhs: EncryptedMessageRecipient) -> Bool {
        return lhs.combinedName == rhs.combinedName
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(userName)
        hasher.combine(deviceName)
    }
    
    
    public let userName: String
    public let deviceName: String
    
    public init(userName: String, deviceName: String) {
        self.userName = userName
        self.deviceName = deviceName
    }
    
    public init(combinedName: String) throws {
        let components = combinedName.components(separatedBy: ":")
        guard components.count == 2 else {throw EncryptionError.invalidCombinedName}
        self.userName = components[0]
        self.deviceName = components[1]
    }
    
    var combinedName: String {
        return "\(self.userName):\(self.deviceName)"
    }
}

public class EncryptedSentMessageOutcome {
    
    public var success: [EncryptedMessageRecipient] = []
    public var failure: [(EncryptedMessageRecipient, Error)] = []
    
}


