import Foundation
import MatrixSDK

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
