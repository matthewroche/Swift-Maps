import Foundation
import OLMKit

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
