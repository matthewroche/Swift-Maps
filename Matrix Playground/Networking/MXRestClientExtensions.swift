//
//  MXRestClientPromise.swift
//  Matrix Playground
//
//  Created by Matthew Roche on 17/06/2020.
//  Copyright © 2020 Matthew Roche. All rights reserved.
//

import Foundation

import Foundation
import MatrixSDK
import Then

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
    Check whether a username is already in use.
    
    - parameters:
        - username: The user name to test.
        - completion: A block object called when the operation is completed.
        - inUse: Whether the username is in use
    
    - returns: a `Promise` instance returning a Bool defining whther the username is in use.
    */
    func isUsernameInUsePromise(username: String) -> Promise<Bool> {
        return Promise { resolve, reject in
            self.isUserNameInUse(username) { response in
                resolve(response)
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
    
    - returns: a `Promise` instance providing a `DarwinBoolean` indicating whether the operation was successful.
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
    
    // MARK: - Device Operations
    /**
    Gets details of a single device
    
    - parameters:
        - deviceId: The deviceId for which we are requesting details.
    
    - returns: a `Promise` instance providing an `MXDevice`.
    */
    func devicePromise(deviceId: String) -> Promise<MXDevice> {
        return Promise { resolve, reject in
            self.device(withId: deviceId) { response in
                switch response {
                case .success(let device):
                    resolve(device)
                case .failure(let error):
                    reject(error)
                }
            }
        }
    }
    
    
    
    // MARK: - Room operations
    
    /**
    Gets a session to allow device deleion on the server
    
    - parameters:
        - toDeleteDevice: The deviceId for which we will request deletion.
    
    - returns: a `Promise` instance providing an `MXAuthenticationSession` to use in deleteDevicePromise.
    */
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
    
    
    /**
    Deletes a device from the server
    
    - parameters:
        - deviceId: The deviceId for which we are requesting deletion.
        - authParameters: The authorisation parameters to validate deletion
    
    - returns: a `Promise` instance providing a Bool defining whether the operation was successful.
    */
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
